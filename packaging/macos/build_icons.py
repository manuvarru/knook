#!/usr/bin/env python3
import sys
import os
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Errore: Pillow non è installato. Esegui: pip install Pillow")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
XC_APPICONSET = REPO_ROOT / "Sources" / "AppShell" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
STATIC_ICNS_PACKAGING = REPO_ROOT / "packaging" / "macos" / "AppIcon.icns"
STATIC_ICNS_RESOURCE = REPO_ROOT / "Sources" / "AppShell" / "Resources" / "AppIcon.icns"
RUNTIME_PNG = REPO_ROOT / "Sources" / "AppShell" / "Resources" / "AppIcon.png"

def draw_squircle(draw, rect, radius, fill):
    """Draws a rounded rectangle using PIL's rounded_rectangle."""
    draw.rounded_rectangle(rect, radius=radius, fill=fill)

def main():
    print("Creazione icona macOS da zero usando Pillow...")
    
    # 1. Crea la canvas di base 1024x1024 con canale Alpha (trasparente)
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 2. Disegna lo squircle bianco centrale (dimensione Big Sur 824x824 centrato)
    # Coordinate: x da 100 a 924, y da 100 a 924
    squircle_rect = [100, 100, 924, 924]
    squircle_radius = 180
    draw_squircle(draw, squircle_rect, squircle_radius, (255, 255, 255, 255))
    
    # 3. Disegna le due barre nere verticali al centro dello squircle
    bar_width = 108
    bar_height = 380
    bar_radius = 32
    bar_gap = 84
    
    total_width = (bar_width * 2) + bar_gap
    first_x = (size - total_width) // 2
    y_start = (size - bar_height) // 2
    
    # Disegna la prima barra
    x1_start = first_x
    bar1_rect = [x1_start, y_start, x1_start + bar_width, y_start + bar_height]
    draw_squircle(draw, bar1_rect, bar_radius, (0, 0, 0, 255))
    
    # Disegna la seconda barra
    x2_start = first_x + bar_width + bar_gap
    bar2_rect = [x2_start, y_start, x2_start + bar_width, y_start + bar_height]
    draw_squircle(draw, bar2_rect, bar_radius, (0, 0, 0, 255))
    
    # 4. Salva i target intermedi
    XC_APPICONSET.mkdir(parents=True, exist_ok=True)
    STATIC_ICNS_PACKAGING.parent.mkdir(parents=True, exist_ok=True)
    
    # Salva il file .icns direttamente usando Pillow (questo impacchetta tutte le risoluzioni corrette!)
    # macOS richiede formati specifici interni, Pillow li gestisce salvando come 'ICNS'
    print(f"Salvataggio file ICNS packaging in: {STATIC_ICNS_PACKAGING}")
    img.save(STATIC_ICNS_PACKAGING, format="ICNS")
    
    # Copia nei file di risorsa statici
    print(f"Copia file ICNS in: {STATIC_ICNS_RESOURCE}")
    img.save(STATIC_ICNS_RESOURCE, format="ICNS")
    
    # Salva l'AppIcon.png a 512x512
    print(f"Salvataggio runtime PNG in: {RUNTIME_PNG}")
    runtime_img = img.resize((512, 512), resample=Image.Resampling.LANCZOS)
    runtime_img.save(RUNTIME_PNG, format="PNG")
    
    # 5. Genera i singoli PNG per l'asset catalog di Xcode (Contents.json è già presente)
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]
    
    print("Generazione PNG per Assets.xcassets...")
    for s, name in sizes:
        resized = img.resize((s, s), resample=Image.Resampling.LANCZOS)
        resized.save(XC_APPICONSET / name, format="PNG")
        
    print("Completato con successo!")

if __name__ == "__main__":
    main()
