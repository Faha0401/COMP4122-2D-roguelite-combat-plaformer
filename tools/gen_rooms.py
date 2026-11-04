#!/usr/bin/env python3
"""Generate identical, simple room layouts for every level scene.

Every room gets the SAME layout (no decorative platforms):
  - 864 x 648 room (1.5x the 576 camera width), floor at y=648.
  - Ground (world boundary) + left/right walls + ceiling.
  - Spawn near bottom-left.
  - Two portals at the right edge, vertically stacked:
      PortalBottom at y=640 (walk into it on the ground)
      PortalTop    at y=540 (reachable by a jump: max jump ~80px)
  - A NameLabel (set to the room name at runtime by room.gd).

Only room_type differs per scene. Nothing else.
"""
import os

ROOT = "/Users/chanching/COMP4122 2D roguelite combat plaformer"
W, H = 864.0, 648.0
FLOOR = 648.0

ROOMS = [
    ("Levels/Combat/Combat1.tscn", "Combat1", "combat"),
    ("Levels/Combat/Combat2.tscn", "Combat2", "combat"),
    ("Levels/Combat/Combat3.tscn", "Combat3", "combat"),
    ("Levels/Combat/Combat4.tscn", "Combat4", "combat"),
    ("Levels/Puzzle/Puzzle1.tscn", "Puzzle1", "puzzle"),
    ("Levels/Puzzle/Puzzle2.tscn", "Puzzle2", "puzzle"),
    ("Levels/Shop/Shop1.tscn", "Shop1", "shop"),
    ("Levels/Shop/Shop2.tscn", "Shop2", "shop"),
    ("Levels/Boss/BossRoom.tscn", "BossRoom", "boss"),
    ("Levels/null_2.tscn", "null_2", "combat"),
]

# Distinct background tints per type so rooms are visibly different.
TYPE_COLORS = {
    "combat": (0.10, 0.09, 0.12),
    "puzzle": (0.13, 0.12, 0.08),
    "shop":   (0.08, 0.12, 0.09),
    "boss":   (0.12, 0.07, 0.15),
}

TEMPLATE = '''[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://Game/room.gd" id="1_room"]
[ext_resource type="PackedScene" path="res://Game/Portal.tscn" id="2_portal"]

[sub_resource type="WorldBoundaryShape2D" id="ground"]

[sub_resource type="RectangleShape2D" id="wall_l"]
size = Vector2(8, 648)

[sub_resource type="RectangleShape2D" id="wall_r"]
size = Vector2(8, 648)

[sub_resource type="RectangleShape2D" id="ceil"]
size = Vector2(864, 8)

[node name="{root}" type="Node2D"]
script = ExtResource("1_room")
room_type = "{rtype}"

[node name="Background" type="ColorRect" parent="."]
z_index = -100
offset_left = 0.0
offset_top = 0.0
offset_right = 864.0
offset_bottom = 648.0
mouse_filter = 2
color = Color({bg0}, {bg1}, {bg2}, 1)

[node name="Ground" type="StaticBody2D" parent="."]

[node name="Col" type="CollisionShape2D" parent="Ground"]
position = Vector2(432.0, 648.0)
shape = SubResource("ground")

[node name="FloorVis" type="ColorRect" parent="."]
z_index = -50
offset_left = 0.0
offset_top = 640.0
offset_right = 864.0
offset_bottom = 648.0
mouse_filter = 2
color = Color(0.2, 0.2, 0.24, 1)

[node name="LeftWall" type="StaticBody2D" parent="."]

[node name="Col" type="CollisionShape2D" parent="LeftWall"]
position = Vector2(4.0, 324.0)
shape = SubResource("wall_l")

[node name="LeftVis" type="ColorRect" parent="."]
z_index = -50
offset_left = 0.0
offset_top = 0.0
offset_right = 8.0
offset_bottom = 648.0
mouse_filter = 2
color = Color(0.3, 0.3, 0.35, 1)

[node name="RightWall" type="StaticBody2D" parent="."]

[node name="Col" type="CollisionShape2D" parent="RightWall"]
position = Vector2(860.0, 324.0)
shape = SubResource("wall_r")

[node name="RightVis" type="ColorRect" parent="."]
z_index = -50
offset_left = 856.0
offset_top = 0.0
offset_right = 864.0
offset_bottom = 648.0
mouse_filter = 2
color = Color(0.3, 0.3, 0.35, 1)

[node name="Ceiling" type="StaticBody2D" parent="."]

[node name="Col" type="CollisionShape2D" parent="Ceiling"]
position = Vector2(432.0, 4.0)
shape = SubResource("ceil")

[node name="Spawn" type="Marker2D" parent="."]
position = Vector2(90, 600)

[node name="NameLabel" type="Label" parent="."]
offset_left = 20.0
offset_top = 16.0
offset_right = 700.0
offset_bottom = 56.0
theme_override_font_sizes/font_size = 28
text = "ROOM"

[node name="PortalTop" parent="." instance=ExtResource("2_portal")]
position = Vector2(804, 540)

[node name="PortalBottom" parent="." instance=ExtResource("2_portal")]
position = Vector2(804, 640)
'''

def main():
    for rel, root, rtype in ROOMS:
        bg = TYPE_COLORS.get(rtype, (0.10, 0.10, 0.12))
        text = TEMPLATE.format(root=root, rtype=rtype, bg0=bg[0], bg1=bg[1], bg2=bg[2])
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
        print("wrote", rel)

if __name__ == "__main__":
    main()