import os

app_name = "Moku"
app_path = os.environ.get("DMG_APP_PATH", f"/tmp/{app_name}.app")
background_path = os.environ.get("DMG_BACKGROUND_PATH", "")

# Volume format
format = "UDBZ"

# Volume size (None = auto)
size = None

# Files to include
files = [app_path]

# Symlinks
symlinks = {"Applications": "/Applications"}

# Icon size in Finder
icon_size = 128

# Window settings
window_rect = ((200, 200), (660, 500))

# Icon positions
icon_locations = {
    f"{app_name}.app": (180, 240),
    "Applications": (480, 240),
}

# Background
if background_path and os.path.isfile(background_path):
    background = background_path
else:
    background = "builtin-arrow"

# Text size
text_size = 14

# Hide extensions
hide_extension = [f"{app_name}.app"]
