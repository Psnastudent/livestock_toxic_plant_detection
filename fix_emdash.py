"""Fix em-dash characters in download_dataset.py and train_toxic_plants.py
so directory names match the actual filesystem folders."""
import re

EM_DASH = "\u2014"  # —

# The actual folder names on disk use em-dashes
FOLDER_NAMES = {
    "1. Abrus precatorius": "Rosary Pea",
    "2. Lantana camara": "Lantana",
    "3. Parthenium hysterophorus": "Congress Grass",
    "4. Pteridium aquilinum": "Bracken Fern",
    "5. Nerium oleander": "Oleander",
    "6. Thevetia peruviana": "Yellow Oleander",
    "7. Calotropis gigantea": "Giant Milkweed",
    "8. Datura stramonium": "Datura  Jimson Weed",
    "9. Mimosa pudica": "Touch-Me-Not",
    "11. Ricinus communis": "Castor",
    "13. Strychnos nux-vomica": "Nux-vomica",
    "14. Gloriosa superba": "Flame Lily",
    "15. Argemone mexicana": "Mexican Poppy",
    "16. Jatropha curcas": "Physic Nut",
    "17. Jatropha multifida": "Coral Plant",
    "19. Antiaris toxicaria": "Upas Tree",
    "20. Cerbera odollam": "Suicide Tree",
    "21. Citrullus colocynthis": "Bitter Apple",
    "22. Unknown": "Other Plants",
}

# Special case: "18. Manihot esculenta —Cassava  Tapioca" has no space after em-dash
SPECIAL = {
    "18. Manihot esculenta --Cassava  Tapioca": f"18. Manihot esculenta {EM_DASH}Cassava  Tapioca",
}

for filename in ["download_dataset.py", "train_toxic_plants.py"]:
    content = open(filename, "r", encoding="utf-8").read()
    changes = 0

    # Replace "X -- Y" with "X — Y" for each known folder
    for prefix, suffix in FOLDER_NAMES.items():
        old = f"{prefix} -- {suffix}"
        new = f"{prefix} {EM_DASH} {suffix}"
        if old in content:
            content = content.replace(old, new)
            changes += 1

    # Special cases
    for old, new in SPECIAL.items():
        if old in content:
            content = content.replace(old, new)
            changes += 1

    # Add encoding fix if not present
    if "sys.stdout.reconfigure" not in content and "import os" in content:
        content = content.replace(
            "import os\n",
            "import os\nimport sys\n",
            1,  # only first occurrence
        )
        # Find first function def or constant and insert before it
        lines = content.split("\n")
        new_lines = []
        inserted = False
        for line in lines:
            if not inserted and line.startswith("# ") and "Path" in line:
                new_lines.append('# Fix Windows console encoding')
                new_lines.append('if hasattr(sys.stdout, "reconfigure"):')
                new_lines.append('    sys.stdout.reconfigure(encoding="utf-8")')
                new_lines.append('')
                inserted = True
            new_lines.append(line)
        if inserted:
            content = "\n".join(new_lines)
            changes += 1

    open(filename, "w", encoding="utf-8").write(content)
    print(f"{filename}: {changes} fixes applied")
