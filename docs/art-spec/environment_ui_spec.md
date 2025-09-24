### SoccerMind Environment & UI Art Spec

- Style: modern broadcast sports; high contrast; crisp edges; subtle AO/soft shadows
- Palette: turf #0F6B3E, turf2 #1F8B50, white #FFFFFF, accents #00E0FF, #A6FF00
- Outputs: 2D PNG/SVG, 3D GLB + PBR 2k, UI SVG

#### Field
- 2D: tiling grass 512/1024; lines overlay SVG + 4k PNG; shadow-only PNG
- 3D: 64×100 m plane; Day/Night materials share UVs; micro-normal grass

#### Goal
- 2D: front/side PNG; net layer; shadow
- 3D: GLB frame + alpha net; collision proxy; 2k PBR; white/graphite variants

#### Ball
- 2D: 8-angle 256 sprites; 64 icon; spin-blur frames; specular layer
- 3D: GLB; stitched normal; cyan/lime accents; PBR 2k

#### Player
- 2D: 8-dir sheets (idle/jog/sprint/pass/shoot/tackle/celebrate), 256 frames
- 3D: <15k tris rig; run/idle/kick/tackle anims; color-mask kits (home/away)

#### Sideline
- Flags (team-colorable), benches, ad boards, cart, camera, light mast, crowd band

#### UI Pack
- Scorebar, possession bar, stamina ring, minimap frame, tooltip, pause panel, icons
- SVG, states (default/hover/pressed/disabled)

#### Godot Integration
- PoT textures; no premultiplied alpha; 2–4 px padding on sprites
- 2D centered pivots; optional normal maps for Light2D
- 3D meters scale; Y-up; origin at base; single UV; clean materials
