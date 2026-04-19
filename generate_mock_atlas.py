from PIL import Image, ImageDraw

# Create a 256x256 image
img = Image.new('RGB', (256, 256), color='white')
d = ImageDraw.Draw(img)

# Material 1: Top Left (Red)
d.rectangle([0, 0, 127, 127], fill=(200, 50, 50))
# Material 2: Top Right (Green)
d.rectangle([128, 0, 255, 127], fill=(50, 200, 50))
# Material 3: Bottom Left (Blue)
d.rectangle([0, 128, 127, 255], fill=(50, 50, 200))
# Material 4: Bottom Right (Yellow)
d.rectangle([128, 128, 255, 255], fill=(200, 200, 50))

img.save('aetheria_engine/assets/atlas_albedo.png')
