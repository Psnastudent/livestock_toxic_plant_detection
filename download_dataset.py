"""
Download dataset images from iNaturalist for toxic plant detection.

Targets:
  - 21 toxic plant classes: ~120 images each
  - 1 Unknown class: ~600 images (diverse non-toxic plants)

Features:
  - Multiple search queries per plant for diversity
  - iNaturalist pagination (up to 200 results per query)
  - Hash-based deduplication (no duplicate images)
  - Corrupt image detection
  - Rate-limited API calls
"""
import os
import sys
import time
import hashlib
import requests
from PIL import Image
from io import BytesIO

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_OF_PLANT_DIR = os.path.join(PROJECT_DIR, "data_of_plant")
UNKNOWN_DIR = os.path.join(DATA_OF_PLANT_DIR, "22. Unknown — Other Plants")

# -- Target counts ------------------------------------------------------
TARGET_PER_TOXIC = 120
TARGET_WEAK = 250
TARGET_UNKNOWN = 1000

WEAK_CLASSES = {
    "11. Ricinus communis — Castor",
    "18. Manihot esculenta —Cassava  Tapioca",
    "12. Ipomoea",
    "20. Cerbera odollam — Suicide Tree",
    "14. Gloriosa superba — Flame Lily",
    "3. Parthenium hysterophorus — Congress Grass",
    "13. Strychnos nux-vomica — Nux-vomica",
}

# -- Toxic plants with multiple search queries for diversity -----------
TOXIC_PLANTS = {
    "1. Abrus precatorius — Rosary Pea": [
        "Abrus precatorius", "rosary pea", "jequirity bean",
    ],
    "2. Lantana camara — Lantana": [
        "Lantana camara", "wild sage lantana", "lantana flower",
    ],
    "3. Parthenium hysterophorus — Congress Grass": [
        "Parthenium hysterophorus", "congress grass", "carrot weed",
    ],
    "4. Pteridium aquilinum — Bracken Fern": [
        "Pteridium aquilinum", "bracken fern", "eagle fern",
    ],
    "5. Nerium oleander — Oleander": [
        "Nerium oleander", "oleander", "oleander flower",
    ],
    "6. Thevetia peruviana — Yellow Oleander": [
        "Thevetia peruviana", "yellow oleander", "cascabela thevetia",
    ],
    "7. Calotropis gigantea — Giant Milkweed": [
        "Calotropis gigantea", "giant milkweed", "crown flower",
    ],
    "8. Datura stramonium — Datura  Jimson Weed": [
        "Datura stramonium", "jimson weed", "thorn apple datura",
    ],
    "9. Mimosa pudica — Touch-Me-Not": [
        "Mimosa pudica", "sensitive plant", "touch me not plant",
    ],
    "10. Immature Sorghum": [
        "Sorghum bicolor", "sorghum plant", "grain sorghum",
    ],
    "11. Ricinus communis — Castor": [
        "Ricinus communis", "castor bean plant", "castor oil plant",
    ],
    "12. Ipomoea": [
        "Ipomoea", "morning glory", "Ipomoea carnea",
    ],
    "13. Strychnos nux-vomica — Nux-vomica": [
        "Strychnos nux-vomica", "nux vomica", "poison nut tree",
    ],
    "14. Gloriosa superba — Flame Lily": [
        "Gloriosa superba", "flame lily", "glory lily",
    ],
    "15. Argemone mexicana — Mexican Poppy": [
        "Argemone mexicana", "mexican prickly poppy", "yellow thistle",
    ],
    "16. Jatropha curcas — Physic Nut": [
        "Jatropha curcas", "physic nut", "purging nut",
    ],
    "17. Jatropha multifida — Coral Plant": [
        "Jatropha multifida", "coral plant", "physic nut coral",
    ],
    "18. Manihot esculenta —Cassava  Tapioca": [
        "Manihot esculenta", "cassava plant", "tapioca plant",
    ],
    "19. Antiaris toxicaria — Upas Tree": [
        "Antiaris toxicaria", "upas tree", "poison arrow tree",
    ],
    "20. Cerbera odollam — Suicide Tree": [
        "Cerbera odollam", "suicide tree", "pong-pong tree",
    ],
    "21. Citrullus colocynthis — Bitter Apple": [
        "Citrullus colocynthis", "bitter apple", "colocynth",
    ],
}

# -- Unknown: Hard Negatives (lookalikes for targets) -----------------
UNKNOWN_PLANTS = [
    # Resembling Castor / Cassava (Palmate/lobed leaves)
    "Fatsia japonica", "Carica papaya", "Liquidambar styraciflua", "Aralia", "Platanus",
    # Resembling Ipomoea / vines / heart leaves
    "Calystegia", "Convolvulus", "Phaseolus", "Dioscorea", "Hedera helix",
    # Resembling Sorghum / grasses
    "Zea mays", "Saccharum officinarum", "Pennisetum", "Panicum virgatum",
    # Resembling Nerium / Thevetia / Cerbera (Long narrow leaves)
    "Salix", "Chamerion angustifolium", "Buddleja davidii", 
    # General difficult / diverse common plants
    "Mangifera indica", "Azadirachta indica", "Cocos nucifera", "Musa",
    "Solanum lycopersicum", "Rosa", "Hibiscus rosa-sinensis", "Ficus benghalensis",
    "Solanum tuberosum", "Allium cepa", "Daucus carota", "Helianthus annuus",
]


# -- Helpers -----------------------------------------------------------

def _file_hash(path):
    """MD5 hash of a file for deduplication."""
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()


def _content_hash(data: bytes):
    """MD5 hash of raw bytes."""
    return hashlib.md5(data).hexdigest()


def _existing_hashes(directory):
    """Collect MD5 hashes of all existing images in a directory."""
    hashes = set()
    if not os.path.exists(directory):
        return hashes
    for fname in os.listdir(directory):
        fpath = os.path.join(directory, fname)
        if fname.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
            try:
                hashes.add(_file_hash(fpath))
            except Exception:
                pass
    return hashes


def _is_valid_image(data: bytes, min_size=5000):
    """Check if raw bytes are a valid, non-tiny image."""
    if len(data) < min_size:
        return False
    try:
        img = Image.open(BytesIO(data))
        img.verify()
        return True
    except Exception:
        return False


def search_inaturalist(taxon_name, limit=60):
    """Search iNaturalist for research-grade photos of a taxon.
    Uses pagination to get up to `limit` photo URLs.
    """
    # 1. Resolve taxon name -> taxon ID
    taxon_url = (
        f"https://api.inaturalist.org/v1/taxa"
        f"?q={requests.utils.quote(taxon_name)}&rank=species,genus"
    )
    try:
        r = requests.get(taxon_url, timeout=15)
        r.raise_for_status()
        results = r.json().get('results', [])
        if not results:
            print(f"    [!] No taxon found for '{taxon_name}'")
            return []
        taxon_id = results[0]['id']
    except Exception as e:
        print(f"    [!] Taxon lookup failed for '{taxon_name}': {e}")
        return []

    # 2. Paginate observations to collect photo URLs
    photo_urls = []
    per_page = min(limit, 200)  # iNaturalist max is 200
    page = 1
    max_pages = (limit // per_page) + 2

    while len(photo_urls) < limit and page <= max_pages:
        obs_url = (
            f"https://api.inaturalist.org/v1/observations"
            f"?taxon_id={taxon_id}&has[]=photos&quality_grade=research"
            f"&per_page={per_page}&page={page}"
            f"&order=desc&order_by=votes"
        )
        try:
            r_obs = requests.get(obs_url, timeout=15)
            r_obs.raise_for_status()
            obs_results = r_obs.json().get('results', [])
            if not obs_results:
                break  # no more results

            for obs in obs_results:
                for photo in obs.get('photos', []):
                    url = photo['url'].replace('square', 'medium')
                    photo_urls.append(url)
                    if len(photo_urls) >= limit:
                        break
                if len(photo_urls) >= limit:
                    break
        except Exception as e:
            print(f"    [!] Observation fetch failed (page {page}): {e}")
            break

        page += 1
        time.sleep(0.5)  # rate limit

    return photo_urls


def download_for_class(class_name, query_names, target_count, target_dir):
    """Download images for a single class, skipping duplicates."""
    os.makedirs(target_dir, exist_ok=True)

    existing_count = len([
        f for f in os.listdir(target_dir)
        if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))
    ])
    if existing_count >= target_count:
        print(f"  [{class_name}] Already has {existing_count}/{target_count} images. Skipping.")
        return 0

    known_hashes = _existing_hashes(target_dir)
    to_download = target_count - existing_count
    total_downloaded = 0

    print(f"  [{class_name}] Have {existing_count}, need {to_download} more ...")

    for query in query_names:
        if to_download <= 0:
            break

        # Request more than needed to account for duplicates / bad images
        urls = search_inaturalist(query, limit=min(to_download + 30, 200))
        print(f"    Query '{query}' -> {len(urls)} candidate URLs")

        for url in urls:
            if to_download <= 0:
                break
            try:
                resp = requests.get(url, timeout=15)
                resp.raise_for_status()
                data = resp.content

                if not _is_valid_image(data):
                    continue

                h = _content_hash(data)
                if h in known_hashes:
                    continue  # duplicate
                known_hashes.add(h)

                safe_q = query.replace(' ', '_').lower()[:20]
                fname = f"inat_{safe_q}_{int(time.time())}_{total_downloaded}.jpg"
                fpath = os.path.join(target_dir, fname)

                with open(fpath, 'wb') as f:
                    f.write(data)

                total_downloaded += 1
                to_download -= 1

            except Exception:
                continue

        time.sleep(1.0)  # rate limit between queries

    final_count = len([
        f for f in os.listdir(target_dir)
        if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))
    ])
    print(f"  [{class_name}] Done: {final_count}/{target_count} images "
          f"(+{total_downloaded} new)")
    return total_downloaded


# -- Main --------------------------------------------------------------

def main():
    print("=" * 60)
    print("Dataset Download -- iNaturalist (research-grade photos)")
    print("=" * 60)
    print(f"Targets: {TARGET_PER_TOXIC} per toxic class, "
          f"{TARGET_UNKNOWN} for Unknown\n")

    # 1. Toxic plants
    print("--- Toxic Plant Classes ---")
    for dir_name, queries in TOXIC_PLANTS.items():
        class_dir = os.path.join(DATA_OF_PLANT_DIR, dir_name)
        target = TARGET_WEAK if dir_name in WEAK_CLASSES else TARGET_PER_TOXIC
        download_for_class(dir_name, queries, target, class_dir)
        print()

    # 2. Unknown / Other
    print("\n--- Unknown Class (non-toxic diversity) ---")
    # Each unknown plant gets a small share of the total
    per_species = max(10, TARGET_UNKNOWN // len(UNKNOWN_PLANTS))
    for plant_name in UNKNOWN_PLANTS:
        existing = len([
            f for f in os.listdir(UNKNOWN_DIR)
            if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))
        ]) if os.path.exists(UNKNOWN_DIR) else 0
        if existing >= TARGET_UNKNOWN:
            print(f"  Unknown class already has {existing}/{TARGET_UNKNOWN}. Done.")
            break
        remaining = TARGET_UNKNOWN - existing
        fetch = min(per_species, remaining)
        download_for_class(f"Unknown ({plant_name})", [plant_name],
                           existing + fetch, UNKNOWN_DIR)

    # Summary
    print("\n" + "=" * 60)
    print("Download Summary")
    print("=" * 60)
    total = 0
    for d in sorted(os.listdir(DATA_OF_PLANT_DIR)):
        dp = os.path.join(DATA_OF_PLANT_DIR, d)
        if os.path.isdir(dp):
            n = len([f for f in os.listdir(dp)
                     if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))])
            status = "[OK]" if n >= 50 else "[!] LOW"
            print(f"  {status} {d}: {n} images")
            total += 1
    print(f"\nTotal classes: {total}")
    print("Done! Next step: run validate_images.py")


if __name__ == '__main__':
    main()
