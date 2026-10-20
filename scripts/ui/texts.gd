class_name Texts
extends RefCounted
## Builds human-readable descriptions from data + translation keys.


static func upgrade_name(id: String) -> String:
	return TranslationServer.translate("U_" + id.to_upper())


static func upgrade_desc(id: String) -> String:
	return TranslationServer.translate("U_" + id.to_upper() + "_DESC")


static func rarity_name(r: String) -> String:
	return TranslationServer.translate("RARITY_" + r.to_upper())


static func tags_text(tags: Array) -> String:
	var parts := []
	for t in tags:
		parts.append(TranslationServer.translate("TAG_" + str(t).to_upper()))
	return " · ".join(parts)


static func synergy_name(id: String) -> String:
	return TranslationServer.translate("SYN_" + id.to_upper())


static func synergy_desc(id: String) -> String:
	var syn: Dictionary = DataDB.synergies().get(id, {})
	var req := []
	for tag in syn.get("requires", {}):
		req.append("%d× %s" % [int(syn.requires[tag]), TranslationServer.translate("TAG_" + str(tag).to_upper())])
	return "%s — %s" % [" + ".join(req), TranslationServer.translate("SYN_" + id.to_upper() + "_DESC")]


static func structure_name(id: String) -> String:
	return TranslationServer.translate(DataDB.structure(id).get("name_key", id))


static func enemy_name(id: String) -> String:
	return TranslationServer.translate(DataDB.enemy(id).get("name_key", id))


static func node_name(type: String) -> String:
	return TranslationServer.translate("NODE_" + type.to_upper())


static func node_reward(type: String) -> String:
	return TranslationServer.translate("NODE_" + type.to_upper() + "_REWARD")


static func time_text(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]
