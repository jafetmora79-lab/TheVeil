extends SceneTree
var failed:=0
func ok(label:String,good:bool):
 print('TEST ',label,' ','PASS' if good else 'FAIL')
 if not good:failed+=1
func _initialize():run.call_deferred()
func frames(n:int):
 for i in n:await process_frame
func run():
 var game=root.get_node('Game')
 for win in [true,false]:
  game.new_game()
  var w=load('res://game/scenes/World.tscn').instantiate()
  root.add_child(w)
  await frames(400)
  w.set_process(false)
  var p=w.player
  p.controls_enabled=true;p.look_enabled=true;p.visible=true;p.health=80
  w.conversing=false;w.in_car=false
  game.flags['p3_mist']=true;game.flags['p3_stepped_out']=true
  w.expedition.start('scavenge', false)
  var e=w.get_node_or_null('OptionalRoofSkitterEncounter')
  if e==null:
   e=load('res://game/encounters/roof_skitter.gd').new()
   e.name='OptionalRoofSkitterEncounter'
   w.add_child(e)
   e.setup(w)
  e.set_process(false)
  p.global_position=e.house.to_global(Vector3(0,.3,19))
  p.set_yaw_pitch(0,0)
  ok('eligible_on_trip', e.eligible())
  e._encounter()
  var elapsed:=0
  while not e.struggling and elapsed<400:
   await process_frame
   elapsed+=1
  ok('struggle_started',e.struggling)
  if win:
   for i in 12:
    var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
    Input.parse_input_event(press)
    var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
    Input.parse_input_event(release)
    await frames(4)
  elapsed=0
  while e.running and elapsed<1200:
   await process_frame
   elapsed+=1
  ok('hiss_faces_lens',e.report.get('anatomical_facing_dot',0.0)>0.85)
  ok('clear_zigzag_left',e.report.get('escaped_left',false) and e.report.get('escape_segments_clear',false) and e.report.get('zigzag_segments',0)>=10)
  ok('ends_hidden_behind_house',e.report.get('hidden_behind_house',false))
  ok('crawls_on_visible_roof', e.report.get('roof_contact_frames',0)>60 and e.report.get('roof_miss_frames',0)==0)
  print('ROOFCONTACT ', e.report.get('roof_contact_frames',0), ' misses ', e.report.get('roof_miss_frames',0))
  ok('feet_on_surfaces',e.report.get('grounded_frames',0)>60 and e.report.get('tip_drop',-1.0)>=0.0 and e.report.get('tip_drop',9.0)<0.8)
  print('ROOF visual bodies %s, roof y %.2f, house y %.2f' % [e.report.get('visual_roof_bodies',0), e.roof.y, e.house.global_position.y])
  print('CONTACT fix up to %.3f m, tip drop %.3f m' % [e.report.get('max_contact_fix',0.0), e.report.get('tip_drop',0.0)])
  ok('health_outcomes',absf(p.health-(80 if win else 40))<0.1)
  ok('control_restored',p.controls_enabled and p.look_enabled)
  print('REPORT ',e.report)
  w.free()
 print('RESULT ','PASS' if failed==0 else str(failed)+' failures')
 quit(0 if failed==0 else 1)
