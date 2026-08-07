class_name EnemyFighterVisualController
extends Node
@export var model_path:NodePath=NodePath("../VisualRoot/SmallSciFiFighter")
var _overlay:StandardMaterial3D
func _ready()->void:
 var model:=get_node_or_null(model_path) as Node3D
 if model==null:return
 _overlay=StandardMaterial3D.new();_overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;_overlay.albedo_color=Color(0.45,0.035,0.025,0.16);_overlay.emission_enabled=true;_overlay.emission=Color(1.0,0.06,0.025,1.0);_overlay.emission_energy_multiplier=0.65
 for n in model.find_children("*","MeshInstance3D",true,false):
  var m:=n as MeshInstance3D
  if m!=null:m.material_overlay=_overlay
 for n in model.find_children("EngineFire*","Node3D",true,false):
  if n is Node3D:(n as Node3D).visible=false
