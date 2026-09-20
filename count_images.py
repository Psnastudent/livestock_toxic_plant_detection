import os

root = "data_of_plant"
for d in sorted(os.listdir(root)):
    dp = os.path.join(root, d)
    if os.path.isdir(dp):
        imgs = [f for f in os.listdir(dp) if f.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))]
        print(f"{d}: {len(imgs)} images")
