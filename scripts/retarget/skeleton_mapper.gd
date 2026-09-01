extends RefCounted
class_name SkeletonMapper

const STAR_TO_TARGET := {
	"root": "hips",
	"pelvis": "hips",
	"spine": "spine",
	"spine1": "spine1",
	"spine2": "spine2",
	"neck": "neck",
	"head": "head",
	"leftshoulder": "leftshoulder",
	"leftarm": "leftarm",
	"leftforearm": "leftforearm",
	"lefthand": "lefthand",
	"rightshoulder": "rightshoulder",
	"rightarm": "rightarm",
	"rightforearm": "rightforearm",
	"righthand": "righthand",
	"leftupleg": "leftupleg",
	"leftleg": "leftleg",
	"leftfoot": "leftfoot",
	"lefttoebase": "lefttoebase",
	"rightupleg": "rightupleg",
	"rightleg": "rightleg",
	"rightfoot": "rightfoot",
	"righttoebase": "righttoebase"
}

func build_mapping(skeleton: Skeleton3D) -> Dictionary:
	var normalized_bones := {}
	for index in skeleton.get_bone_count():
		normalized_bones[normalize_name(skeleton.get_bone_name(index))] = skeleton.get_bone_name(index)
	var mapping := {}
	for star_joint in STAR_TO_TARGET:
		var target_key: String = STAR_TO_TARGET[star_joint]
		if normalized_bones.has(target_key):
			mapping[star_joint] = normalized_bones[target_key]
	return mapping

func normalize_name(value: String) -> String:
	var result := value.to_lower()
	for prefix in ["mixamorig:", "mixamorig_", "armature|", "armature:"]:
		result = result.replace(prefix, "")
	for character in ["_", "-", " ", "."]:
		result = result.replace(character, "")
	return result
