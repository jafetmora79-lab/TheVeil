"""Blender (5.x) assembly of the game preview: the raw AVI that Godot's movie writer made (picture + the game's own sound) becomes the finished H.264 / AAC MP4.
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python game/preview/assemble_preview.py -- <raw.avi> <out.mp4> [fps]
A light grade (a touch of contrast, the shadows pulled blue-green) is put on the strip; nothing else is added: titles, bars and grain are in the footage."""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
raw, out = argv[0], argv[1]

sc = bpy.context.scene
sc.render.resolution_x = 1920
sc.render.resolution_y = 1080
sc.render.resolution_percentage = 100
sc.render.fps = int(argv[2]) if len(argv) > 2 else 30
sc.sequence_editor_create()
se = sc.sequence_editor
strips = se.strips if hasattr(se, "strips") else se.sequences
v = strips.new_movie("preview", raw, channel=1, frame_start=1)
try:
    a = strips.new_sound("sound", raw, channel=2, frame_start=1)
except Exception as e:                       # (a file with no sound track)
    print("NO SOUND", e)
sc.frame_start = 1
sc.frame_end = v.frame_final_duration
try:
    m = v.modifiers.new(name="grade", type="BRIGHT_CONTRAST")
    m.bright = 0.02
    m.contrast = 0.12
except Exception as e:
    print("GRADE SKIPPED", e)
try:
    sc.render.image_settings.media_type = "VIDEO"          # (Blender 5: video output is a media type first)
except Exception as e:
    print("MEDIA TYPE", e)
sc.render.image_settings.file_format = "FFMPEG"
sc.render.ffmpeg.format = "MPEG4"
sc.render.ffmpeg.codec = "H264"
sc.render.ffmpeg.constant_rate_factor = "HIGH"
sc.render.ffmpeg.ffmpeg_preset = "GOOD"
sc.render.ffmpeg.audio_codec = "AAC"
sc.render.ffmpeg.audio_bitrate = 192
sc.render.filepath = out
print("ASSEMBLE frames", sc.frame_end, "->", out)
bpy.ops.render.render(animation=True)
print("ASSEMBLE done")
