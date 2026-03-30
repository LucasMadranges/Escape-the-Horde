extends RefCounted


static func build(player_node: Node) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 5
	player_node.add_child(layer)

	var ko_overlay := ColorRect.new()
	ko_overlay.anchor_left = 0.0
	ko_overlay.anchor_top = 0.0
	ko_overlay.anchor_right = 1.0
	ko_overlay.anchor_bottom = 1.0
	ko_overlay.offset_left = 0.0
	ko_overlay.offset_top = 0.0
	ko_overlay.offset_right = 0.0
	ko_overlay.offset_bottom = 0.0
	ko_overlay.color = Color(0.45, 0.03, 0.03, 0.36)
	ko_overlay.visible = false
	layer.add_child(ko_overlay)

	var ko_title_label := Label.new()
	ko_title_label.anchor_left = 0.5
	ko_title_label.anchor_top = 0.5
	ko_title_label.anchor_right = 0.5
	ko_title_label.anchor_bottom = 0.5
	ko_title_label.offset_left = -220.0
	ko_title_label.offset_top = -48.0
	ko_title_label.offset_right = 220.0
	ko_title_label.offset_bottom = -8.0
	ko_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ko_title_label.add_theme_font_size_override("font_size", 34)
	ko_title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.82))
	ko_title_label.text = ""
	ko_overlay.add_child(ko_title_label)

	var ko_subtitle_label := Label.new()
	ko_subtitle_label.anchor_left = 0.5
	ko_subtitle_label.anchor_top = 0.5
	ko_subtitle_label.anchor_right = 0.5
	ko_subtitle_label.anchor_bottom = 0.5
	ko_subtitle_label.offset_left = -220.0
	ko_subtitle_label.offset_top = 0.0
	ko_subtitle_label.offset_right = 220.0
	ko_subtitle_label.offset_bottom = 40.0
	ko_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ko_subtitle_label.add_theme_font_size_override("font_size", 22)
	ko_subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.94))
	ko_subtitle_label.text = ""
	ko_overlay.add_child(ko_subtitle_label)

	var revive_prompt_label := Label.new()
	revive_prompt_label.anchor_left = 0.5
	revive_prompt_label.anchor_top = 1.0
	revive_prompt_label.anchor_right = 0.5
	revive_prompt_label.anchor_bottom = 1.0
	revive_prompt_label.offset_left = -220.0
	revive_prompt_label.offset_top = -110.0
	revive_prompt_label.offset_right = 220.0
	revive_prompt_label.offset_bottom = -76.0
	revive_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revive_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	revive_prompt_label.add_theme_font_size_override("font_size", 19)
	revive_prompt_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95))
	revive_prompt_label.text = ""
	revive_prompt_label.visible = false
	layer.add_child(revive_prompt_label)

	var revive_progress_bar := ProgressBar.new()
	revive_progress_bar.anchor_left = 0.5
	revive_progress_bar.anchor_top = 1.0
	revive_progress_bar.anchor_right = 0.5
	revive_progress_bar.anchor_bottom = 1.0
	revive_progress_bar.offset_left = -130.0
	revive_progress_bar.offset_top = -74.0
	revive_progress_bar.offset_right = 130.0
	revive_progress_bar.offset_bottom = -56.0
	revive_progress_bar.min_value = 0.0
	revive_progress_bar.max_value = 100.0
	revive_progress_bar.value = 0.0
	revive_progress_bar.show_percentage = false
	revive_progress_bar.visible = false
	layer.add_child(revive_progress_bar)

	return {
		"overlay": ko_overlay,
		"title": ko_title_label,
		"subtitle": ko_subtitle_label,
		"prompt": revive_prompt_label,
		"progress": revive_progress_bar,
	}
