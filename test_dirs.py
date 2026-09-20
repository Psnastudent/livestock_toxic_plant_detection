"""Quick test: verify download_dataset.py folder names match filesystem."""
import os, sys, re
sys.stdout.reconfigure(encoding='utf-8')

data_dir = 'data_of_plant'
actual = set(os.listdir(data_dir))

content = open('download_dataset.py', 'r', encoding='utf-8').read()
pattern = r'"(\d+\..+?)":\s*\['
dirs_in_script = re.findall(pattern, content)
dirs_in_script.append('22. Unknown \u2014 Other Plants')

print("Checking script dir names vs filesystem:")
all_ok = True
for d in dirs_in_script:
    status = 'OK' if d in actual else 'MISSING'
    if status == 'MISSING':
        all_ok = False
    print(f'  {status:7s} {d}')

print(f'\nAll matched: {all_ok}')
