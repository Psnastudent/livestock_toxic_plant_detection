"""
Validate downloaded dataset images BEFORE training.

Checks:
  1. Corrupt / unreadable images
  2. Duplicate images across ALL classes (MD5 hash)
  3. Unusually small images (likely icons/thumbnails)
  4. Unusually large images (possible irrelevant photos)
  5. Image dimension statistics per class
  6. Generates a validation report

Usage:
    python validate_images.py
"""
import os
import hashlib
import json
from collections import defaultdict
from PIL import Image

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(PROJECT_DIR, "data_of_plant")
REPORT_PATH = os.path.join(PROJECT_DIR, "validation_report.txt")

IMAGE_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.webp')
MIN_DIMENSION = 50       # images smaller than 50x50 are suspicious
MIN_FILE_SIZE = 3000     # files smaller than 3KB are suspicious
MAX_FILE_SIZE = 15_000_000  # files larger than 15MB are suspicious


def file_hash(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()


def validate_image(path):
    """Returns (is_valid, width, height, file_size, issues)."""
    issues = []
    file_size = os.path.getsize(path)

    if file_size < MIN_FILE_SIZE:
        issues.append(f"tiny file ({file_size} bytes)")
    if file_size > MAX_FILE_SIZE:
        issues.append(f"very large file ({file_size / 1e6:.1f} MB)")

    try:
        with Image.open(path) as img:
            img.verify()
        # Re-open after verify (verify can close the file)
        with Image.open(path) as img:
            w, h = img.size
            if w < MIN_DIMENSION or h < MIN_DIMENSION:
                issues.append(f"small dimensions ({w}x{h})")
    except Exception as e:
        return False, 0, 0, file_size, [f"corrupt/unreadable: {e}"]

    return True, w, h, file_size, issues


def main():
    print("=" * 60)
    print("Dataset Validation Report")
    print("=" * 60)

    if not os.path.exists(DATA_DIR):
        print(f"ERROR: {DATA_DIR} not found!")
        return

    # Global hash -> list of (class, filename)
    global_hashes = defaultdict(list)
    class_stats = {}
    all_issues = []
    total_images = 0
    total_corrupt = 0
    total_issues = 0

    class_dirs = sorted(os.listdir(DATA_DIR))

    for class_name in class_dirs:
        class_path = os.path.join(DATA_DIR, class_name)
        if not os.path.isdir(class_path):
            continue

        images = [f for f in os.listdir(class_path)
                  if f.lower().endswith(IMAGE_EXTENSIONS)]

        if not images:
            print(f"\n  [!] {class_name}: NO IMAGES")
            class_stats[class_name] = {"count": 0, "issues": ["no images"]}
            continue

        widths, heights, sizes = [], [], []
        class_issues = []
        corrupt_count = 0

        for img_file in images:
            img_path = os.path.join(class_path, img_file)
            is_valid, w, h, fsize, issues = validate_image(img_path)

            if not is_valid:
                corrupt_count += 1
                total_corrupt += 1
                class_issues.append(f"  CORRUPT: {img_file} -- {issues}")
                all_issues.append(f"[{class_name}] CORRUPT: {img_file}")
                continue

            widths.append(w)
            heights.append(h)
            sizes.append(fsize)

            if issues:
                total_issues += 1
                for issue in issues:
                    class_issues.append(f"  WARNING: {img_file} -- {issue}")
                    all_issues.append(f"[{class_name}] {img_file}: {issue}")

            # Track hash for cross-class duplicate detection
            try:
                h_val = file_hash(img_path)
                global_hashes[h_val].append((class_name, img_file))
            except Exception:
                pass

        total_images += len(images)

        avg_w = sum(widths) / len(widths) if widths else 0
        avg_h = sum(heights) / len(heights) if heights else 0
        avg_size = sum(sizes) / len(sizes) if sizes else 0

        status = "[OK]" if len(images) >= 50 and corrupt_count == 0 else "[!]"
        print(f"\n  {status} {class_name}")
        print(f"    Images: {len(images)}  |  Corrupt: {corrupt_count}")
        print(f"    Avg size: {avg_w:.0f}x{avg_h:.0f}  |  Avg file: {avg_size/1024:.0f} KB")

        if class_issues:
            for ci in class_issues[:5]:  # show first 5 issues
                print(f"    {ci}")
            if len(class_issues) > 5:
                print(f"    ... and {len(class_issues) - 5} more issues")

        class_stats[class_name] = {
            "count": len(images),
            "corrupt": corrupt_count,
            "avg_dimensions": f"{avg_w:.0f}x{avg_h:.0f}",
            "avg_file_kb": round(avg_size / 1024),
            "issues": len(class_issues),
        }

    # Cross-class duplicates
    print("\n" + "=" * 60)
    print("Cross-Class Duplicate Check")
    print("=" * 60)
    cross_dupes = {h: locs for h, locs in global_hashes.items()
                   if len(set(cls for cls, _ in locs)) > 1}

    if cross_dupes:
        print(f"\n  [!] Found {len(cross_dupes)} images appearing in MULTIPLE classes:\n")
        for h, locations in list(cross_dupes.items())[:20]:
            classes = [f"{cls}/{fn}" for cls, fn in locations]
            print(f"    Hash {h[:10]}... found in: {', '.join(classes)}")
        all_issues.append(f"CROSS-CLASS DUPLICATES: {len(cross_dupes)} images")
    else:
        print("  [OK] No cross-class duplicates found.")

    # Within-class duplicates
    within_dupes = {h: locs for h, locs in global_hashes.items()
                    if len(locs) > 1 and len(set(cls for cls, _ in locs)) == 1}
    if within_dupes:
        print(f"\n  [!] Found {len(within_dupes)} within-class duplicates:")
        for h, locations in list(within_dupes.items())[:10]:
            cls = locations[0][0]
            files = [fn for _, fn in locations]
            print(f"    {cls}: {', '.join(files)}")
    else:
        print("  [OK] No within-class duplicates found.")

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"  Total classes:          {len(class_stats)}")
    print(f"  Total images:           {total_images}")
    print(f"  Corrupt images:         {total_corrupt}")
    print(f"  Images with warnings:   {total_issues}")
    print(f"  Cross-class duplicates: {len(cross_dupes)}")
    print(f"  Within-class duplicates:{len(within_dupes)}")

    low_classes = [name for name, s in class_stats.items()
                   if s.get("count", 0) < 50]
    if low_classes:
        print(f"\n  [!] Classes with < 50 images:")
        for c in low_classes:
            print(f"    - {c}: {class_stats[c]['count']} images")

    if total_corrupt == 0 and len(cross_dupes) == 0 and not low_classes:
        print("\n  [OK] Dataset looks CLEAN. Ready for training split.")
    else:
        print("\n  [!] Issues found. Review above and fix before training.")

    # Save report
    report = {
        "total_images": total_images,
        "total_corrupt": total_corrupt,
        "cross_class_duplicates": len(cross_dupes),
        "within_class_duplicates": len(within_dupes),
        "classes": class_stats,
        "issues": all_issues[:50],
    }

    with open(REPORT_PATH, 'w') as f:
        f.write("DATASET VALIDATION REPORT\n")
        f.write("=" * 40 + "\n\n")
        f.write(json.dumps(report, indent=2))

    print(f"\n  Report saved to: {REPORT_PATH}")


if __name__ == '__main__':
    main()
