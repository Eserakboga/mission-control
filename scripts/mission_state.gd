extends Node

const COMPONENTS := {
	"structure": {"name": "STRUCTURE", "cost_m": 35, "mass_kg": 260, "power_w": -12, "data_gb_day": 0, "battery_wh": 0, "description": "Primary spacecraft bus and load-bearing frame.", "technical_reference": "NASA SmallSat SST §6: structure and dispenser interfaces must accommodate launch mechanical loads; geometry and requirements are vehicle-specific."},
	"solar_panels": {"name": "SOLAR PANELS", "cost_m": 25, "mass_kg": 110, "power_w": 220, "data_gb_day": 0, "battery_wh": 0, "description": "Generates electrical power while in sunlight.", "technical_reference": "NASA SmallSat SST §3.2: arrays combine series cell strings and parallel circuits; deployed array size, substrate, deployment and pointing effects are design considerations."},
	"battery": {"name": "BATTERY", "cost_m": 16, "mass_kg": 75, "power_w": -3, "data_gb_day": 0, "battery_wh": 1200, "description": "Stores 1,200 Wh for eclipse and peak loads.", "technical_reference": "NASA SmallSat SST §3: usable system energy also depends on battery management and thermal controls. The 1,200 Wh game value is hypothetical, not NASA hardware data."},
	"communication_antenna": {"name": "COMMUNICATION ANTENNA", "cost_m": 11, "mass_kg": 42, "power_w": -18, "data_gb_day": 2, "battery_wh": 0, "description": "Downlinks mission data to ground control.", "technical_reference": "NASA SmallSat SST §9: uplink, downlink and crosslink are separate functions; link rate, antenna gain and pointing constraints trade against one another."},
	"onboard_computer": {"name": "ONBOARD COMPUTER", "cost_m": 15, "mass_kg": 30, "power_w": -32, "data_gb_day": 6, "battery_wh": 0, "description": "Guidance, navigation and payload control.", "technical_reference": "NASA SmallSat SST §11: mission operations architectures handle command, telemetry and housekeeping data through ground-segment systems. This is operational context, not a computer specification."},
	"scientific_camera": {"name": "SCIENTIFIC CAMERA", "cost_m": 19, "mass_kg": 45, "power_w": -24, "data_gb_day": 16, "battery_wh": 0, "description": "High-resolution visual and climate imaging."},
	"radar": {"name": "RADAR", "cost_m": 42, "mass_kg": 120, "power_w": -68, "data_gb_day": 24, "battery_wh": 0, "description": "Surface mapping and subsurface sounding."},
	"spectrometer": {"name": "SPECTROMETER", "cost_m": 38, "mass_kg": 78, "power_w": -52, "data_gb_day": 20, "battery_wh": 0, "description": "Measures material composition by spectrum."}
}

const ROCKETS := {
	"light": {"name": "LIGHT LAUNCH VEHICLE", "capacity_kg": 700, "cost_m": 32, "description": "Compact, cost-efficient launcher for focused orbital payloads."},
	"medium": {"name": "MEDIUM LAUNCH VEHICLE", "capacity_kg": 1600, "cost_m": 86, "description": "Balanced lift for larger spacecraft and multi-system payloads."},
	"heavy": {"name": "HEAVY LAUNCH VEHICLE", "capacity_kg": 4800, "cost_m": 240, "description": "High-energy lift with generous payload margin for distant missions."}
}

const ORBITS := {
	"leo": {"name": "LOW EARTH ORBIT (LEO)", "body": "EARTH", "altitude": "~400 KM", "period": "~92 MIN", "communication_pct": 95, "observation_pct": 90, "duration_factor": 1.0, "compatible": ["earth_observation"], "advantage": "Low latency and frequent ground contact.", "drawback": "Coverage is intermittent; high latitudes are less consistent."},
	"sso": {"name": "SUN-SYNCHRONOUS ORBIT (SSO)", "body": "EARTH", "altitude": "~600 KM POLAR", "period": "~97 MIN", "communication_pct": 82, "observation_pct": 125, "duration_factor": 1.05, "compatible": ["earth_observation"], "advantage": "Consistent local solar time for repeatable imaging.", "drawback": "Higher inclination and fewer direct ground passes."},
	"geo": {"name": "GEOSTATIONARY ORBIT (GEO)", "body": "EARTH", "altitude": "35,786 KM", "period": "24 HOURS", "communication_pct": 100, "observation_pct": 72, "duration_factor": 0.9, "compatible": ["earth_observation"], "advantage": "Continuous view and strong communications over one region.", "drawback": "Poor polar coverage and lower detail at great distance."},
	"lunar": {"name": "LUNAR ORBIT", "body": "THE MOON", "altitude": "~100 KM", "period": "~2 HOURS", "communication_pct": 68, "observation_pct": 110, "duration_factor": 1.0, "compatible": ["lunar_exploration"], "advantage": "Close surface mapping with short orbital passes.", "drawback": "Far-side communications need relay coverage."},
	"mars": {"name": "MARS ORBIT", "body": "MARS", "altitude": "~300 KM", "period": "~8 HOURS", "communication_pct": 46, "observation_pct": 108, "duration_factor": 1.12, "compatible": ["mars_exploration"], "advantage": "Global science coverage and repeated regional passes.", "drawback": "Long light-time delay and limited real-time control."},
	"deep_space": {"name": "DEEP SPACE TRAJECTORY", "body": "DEEP SPACE", "altitude": "INTERPLANETARY", "period": "TRAJECTORY", "communication_pct": 22, "observation_pct": 62, "duration_factor": 1.35, "compatible": ["deep_space"], "advantage": "Opens access to distant outer-system targets.", "drawback": "Very low data rate, long signal delay and extended cruise."}
}

## Shared mission and spacecraft state for the current game session.
var selected_mission: Dictionary = {}
var spacecraft_design: Dictionary = {}
var active_components: Array[String] = []
var design_summary: Dictionary = {}
var selected_rocket_id := ""
var selected_orbit_id := ""
var launch_summary: Dictionary = {}
var launch_plan: Dictionary = {}
var mission_simulation: Dictionary = {}
var mission_report: Dictionary = {}
var mission_history: Array[Dictionary] = []
var audio_settings := {"master": 0.8, "music": 0.35, "sfx": 0.7, "music_enabled": true, "sfx_enabled": true}
var sandbox_mode := false
var nasa_planetary_data: Dictionary = {}

const HISTORY_PATH := "user://mission_history.json"
const SETTINGS_PATH := "user://player_settings.cfg"
const NASA_PLANETARY_DATA_PATH := "res://data/nasa_planetary_data.json"

func _ready() -> void:
	_load_nasa_planetary_data()
	_load_local_data()

func _load_nasa_planetary_data() -> void:
	if not FileAccess.file_exists(NASA_PLANETARY_DATA_PATH):
		push_warning("NASA planetary dataset is missing; mission planning will continue without body facts.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NASA_PLANETARY_DATA_PATH))
	if parsed is Dictionary and parsed.get("bodies", {}) is Dictionary:
		nasa_planetary_data = parsed
	else:
		push_warning("NASA planetary dataset could not be parsed; mission planning will continue without body facts.")

func planetary_body_key(target: String) -> String:
	var normalized := target.strip_edges().to_lower().replace("the ", "")
	if normalized in ["outer system", "deep space"]:
		return ""
	return normalized

func planetary_facts(target: String) -> Dictionary:
	var body_key := planetary_body_key(target)
	var bodies: Dictionary = nasa_planetary_data.get("bodies", {})
	if body_key.is_empty() or not bodies.has(body_key):
		return {}
	return bodies[body_key].duplicate(true)

func _load_local_data() -> void:
	if FileAccess.file_exists(HISTORY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_PATH))
		if parsed is Array:
			mission_history.clear()
			for entry in parsed:
				if entry is Dictionary:
					mission_history.append(entry)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		audio_settings["master"] = float(config.get_value("audio", "master", 0.8))
		audio_settings["music"] = float(config.get_value("audio", "music", 0.35))
		audio_settings["sfx"] = float(config.get_value("audio", "sfx", 0.7))
		audio_settings["music_enabled"] = bool(config.get_value("audio", "music_enabled", true))
		audio_settings["sfx_enabled"] = bool(config.get_value("audio", "sfx_enabled", true))
	_apply_audio_settings()

func save_audio_settings() -> void:
	var config := ConfigFile.new()
	for key in audio_settings:
		config.set_value("audio", key, audio_settings[key])
	config.save(SETTINGS_PATH)
	_apply_audio_settings()

func _apply_audio_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(audio_settings["master"]))))
	AudioServer.set_bus_mute(0, float(audio_settings["master"]) <= 0.001)

const MISSION_PHASES := [
	{"name": "LAUNCH"},
	{"name": "ORBIT INSERTION"},
	{"name": "INSTRUMENT ACTIVATION"},
	{"name": "SCIENCE OPERATIONS"},
	{"name": "DATA TRANSMISSION"},
	{"name": "MISSION COMPLETE"}
]

func set_selected_mission(mission: Dictionary) -> void:
	selected_mission = mission.duplicate(true)
	sandbox_mode = selected_mission.get("id", "") == "sandbox"

func begin_spacecraft_design() -> Dictionary:
	active_components.clear()
	for component_id in selected_mission.get("required_components", []):
		if COMPONENTS.has(component_id):
			active_components.append(component_id)
	design_summary = calculate_design()
	spacecraft_design.clear()
	return design_summary.duplicate(true)

func toggle_component(component_id: String) -> Dictionary:
	if not COMPONENTS.has(component_id):
		return design_summary.duplicate(true)
	if active_components.has(component_id):
		active_components.erase(component_id)
	else:
		active_components.append(component_id)
	design_summary = calculate_design()
	return design_summary.duplicate(true)

func calculate_design() -> Dictionary:
	var budget_limit_m := int(selected_mission.get("budget_millions", 0))
	var mass_limit_kg := _mass_limit_for(selected_mission.get("id", ""))
	var cost_m := 0
	var mass_kg := 0
	var power_generation_w := 0
	var power_load_w := 0
	var data_capacity_gb_day := 0
	var battery_capacity_wh := 0
	for component_id in active_components:
		if not COMPONENTS.has(component_id):
			continue
		var component: Dictionary = COMPONENTS[component_id]
		cost_m += int(component["cost_m"])
		mass_kg += int(component["mass_kg"])
		var component_power := int(component["power_w"])
		if component_power > 0:
			power_generation_w += component_power
		else:
			power_load_w += absi(component_power)
		data_capacity_gb_day += int(component["data_gb_day"])
		battery_capacity_wh += int(component["battery_wh"])
	var missing: Array[String] = []
	for component_id in selected_mission.get("required_components", []):
		if not active_components.has(component_id):
			missing.append(component_id)
	var data_required := int(selected_mission.get("data_requirement_gb_day", 0))
	var valid := cost_m <= budget_limit_m and mass_kg <= mass_limit_kg and missing.is_empty() and power_generation_w >= power_load_w and data_capacity_gb_day >= data_required
	if sandbox_mode:
		valid = cost_m <= budget_limit_m and mass_kg <= mass_limit_kg
	var warnings: Array[String] = []
	if cost_m > budget_limit_m:
		warnings.append("BUDGET LIMIT EXCEEDED")
	if mass_kg > mass_limit_kg:
		warnings.append("MASS LIMIT EXCEEDED")
	if not missing.is_empty() and not sandbox_mode:
		warnings.append("REQUIRED EQUIPMENT MISSING")
	if power_generation_w < power_load_w and not sandbox_mode:
		warnings.append("POWER LOAD EXCEEDS GENERATION")
	if data_capacity_gb_day < data_required and not sandbox_mode:
		warnings.append("DATA CAPACITY BELOW MISSION REQUIREMENT")
	return {
		"valid": valid,
		"cost_m": cost_m,
		"budget_limit_m": budget_limit_m,
		"budget_remaining_m": budget_limit_m - cost_m,
		"mass_kg": mass_kg,
		"mass_limit_kg": mass_limit_kg,
		"power_generation_w": power_generation_w,
		"power_load_w": power_load_w,
		"power_net_w": power_generation_w - power_load_w,
		"data_capacity_gb_day": data_capacity_gb_day,
		"data_requirement_gb_day": data_required,
		"battery_capacity_wh": battery_capacity_wh,
		"missing_components": missing,
		"warnings": warnings
	}

func save_spacecraft_design() -> Dictionary:
	design_summary = calculate_design()
	spacecraft_design = {
		"mission_id": selected_mission.get("id", ""),
		"mission_name": selected_mission.get("name", ""),
		"components": active_components.duplicate(),
		"resources": design_summary.duplicate(true),
		"valid": design_summary.get("valid", false)
	}
	return spacecraft_design.duplicate(true)

func begin_launch_selection() -> void:
	selected_rocket_id = ""
	selected_orbit_id = ""
	launch_plan.clear()
	launch_summary = calculate_launch()

func select_rocket(rocket_id: String) -> Dictionary:
	if ROCKETS.has(rocket_id):
		selected_rocket_id = rocket_id
	launch_summary = calculate_launch()
	return launch_summary.duplicate(true)

func select_orbit(orbit_id: String) -> Dictionary:
	if ORBITS.has(orbit_id) and is_orbit_compatible(orbit_id):
		selected_orbit_id = orbit_id
	launch_summary = calculate_launch()
	return launch_summary.duplicate(true)

func is_orbit_compatible(orbit_id: String) -> bool:
	if not ORBITS.has(orbit_id):
		return false
	return selected_mission.get("id", "") in ORBITS[orbit_id]["compatible"]

func calculate_launch() -> Dictionary:
	var mission_budget := int(selected_mission.get("budget_millions", 0))
	var spacecraft_cost := int(spacecraft_design.get("resources", design_summary).get("cost_m", 0))
	var spacecraft_mass := int(spacecraft_design.get("resources", design_summary).get("mass_kg", 0))
	var rocket: Dictionary = ROCKETS.get(selected_rocket_id, {})
	var orbit: Dictionary = ORBITS.get(selected_orbit_id, {})
	var rocket_cost := int(rocket.get("cost_m", 0))
	var rocket_capacity := int(rocket.get("capacity_kg", 0))
	var total_cost := spacecraft_cost + rocket_cost
	var budget_remaining := mission_budget - total_cost
	var capacity_ok := not rocket.is_empty() and spacecraft_mass <= rocket_capacity
	var budget_ok := not rocket.is_empty() and total_cost <= mission_budget
	var orbit_ok := not orbit.is_empty() and is_orbit_compatible(selected_orbit_id)
	var warnings: Array[String] = []
	if not spacecraft_design.get("valid", false):
		warnings.append("SPACECRAFT DESIGN IS NOT SAVED OR VALID")
	if selected_rocket_id.is_empty():
		warnings.append("SELECT A LAUNCH VEHICLE")
	elif not capacity_ok:
		warnings.append("ROCKET PAYLOAD CAPACITY EXCEEDED")
	if not rocket.is_empty() and not budget_ok:
		warnings.append("TOTAL MISSION BUDGET EXCEEDED")
	if selected_orbit_id.is_empty():
		warnings.append("SELECT A MISSION-COMPATIBLE ORBIT")
	elif not orbit_ok:
		warnings.append("ORBIT IS NOT COMPATIBLE WITH THIS MISSION")
	var base_days := int(selected_mission.get("duration_days", 1))
	var duration_days := roundi(float(base_days) * float(orbit.get("duration_factor", 1.0)))
	return {
		"valid": spacecraft_design.get("valid", false) and capacity_ok and budget_ok and orbit_ok,
		"spacecraft_mass_kg": spacecraft_mass,
		"rocket_capacity_kg": rocket_capacity,
		"spacecraft_cost_m": spacecraft_cost,
		"rocket_cost_m": rocket_cost,
		"mission_budget_m": mission_budget,
		"total_cost_m": total_cost,
		"budget_remaining_m": budget_remaining,
		"duration_days": duration_days,
		"communication_pct": int(orbit.get("communication_pct", 0)),
		"observation_pct": int(orbit.get("observation_pct", 0)),
		"warnings": warnings
	}

func save_launch_plan() -> Dictionary:
	launch_summary = calculate_launch()
	if not launch_summary.get("valid", false):
		return {}
	launch_plan = {
		"mission": selected_mission.duplicate(true),
		"spacecraft_design": spacecraft_design.duplicate(true),
		"rocket_id": selected_rocket_id,
		"rocket": ROCKETS[selected_rocket_id].duplicate(true),
		"orbit_id": selected_orbit_id,
		"orbit": ORBITS[selected_orbit_id].duplicate(true),
		"summary": launch_summary.duplicate(true)
	}
	return launch_plan.duplicate(true)

func evaluate_preflight() -> Dictionary:
	var checks: Array[Dictionary] = []
	var mission_matches: bool = not selected_mission.is_empty() and launch_plan.get("mission", {}).get("id", "") == selected_mission.get("id", "")
	checks.append({"name": "MISSION PROFILE", "valid": mission_matches, "detail": selected_mission.get("name", "NO MISSION SELECTED")})
	var saved_design: Dictionary = launch_plan.get("spacecraft_design", {})
	var design_resources: Dictionary = saved_design.get("resources", {})
	var design_valid: bool = bool(saved_design.get("valid", false)) and not design_resources.is_empty()
	checks.append({"name": "SPACECRAFT DESIGN", "valid": design_valid, "detail": "%d CONFIGURED SYSTEMS" % saved_design.get("components", []).size()})
	var rocket: Dictionary = launch_plan.get("rocket", {})
	var orbit: Dictionary = launch_plan.get("orbit", {})
	var summary: Dictionary = launch_plan.get("summary", {})
	var mass_ok := not rocket.is_empty() and int(design_resources.get("mass_kg", 0)) <= int(rocket.get("capacity_kg", 0))
	checks.append({"name": "PAYLOAD CAPACITY", "valid": mass_ok, "detail": "%d / %d KG" % [design_resources.get("mass_kg", 0), rocket.get("capacity_kg", 0)]})
	var funds_ok := not summary.is_empty() and int(summary.get("budget_remaining_m", -1)) >= 0
	checks.append({"name": "MISSION BUDGET", "valid": funds_ok, "detail": "%s REMAINING" % _format_millions(int(summary.get("budget_remaining_m", 0)))})
	var energy_ok := int(design_resources.get("power_generation_w", 0)) >= int(design_resources.get("power_load_w", 0)) and int(design_resources.get("power_generation_w", 0)) > 0
	checks.append({"name": "ENERGY BALANCE", "valid": energy_ok, "detail": "%d W GENERATION / %d W LOAD" % [design_resources.get("power_generation_w", 0), design_resources.get("power_load_w", 0)]})
	var antenna_installed: bool = saved_design.get("components", []).has("communication_antenna")
	var comms_ok := not orbit.is_empty() and antenna_installed and int(orbit.get("communication_pct", 0)) > 0
	checks.append({"name": "COMMUNICATION LINK", "valid": comms_ok, "detail": "%d%% LINK QUALITY" % orbit.get("communication_pct", 0) if not orbit.is_empty() else "NO ORBIT SELECTED"})
	var orbit_ok := not orbit.is_empty() and is_orbit_compatible(str(launch_plan.get("orbit_id", "")))
	checks.append({"name": "TRAJECTORY", "valid": orbit_ok, "detail": orbit.get("name", "NO COMPATIBLE ORBIT")})
	var valid := not checks.is_empty()
	for check in checks:
		valid = valid and check["valid"]
	return {"valid": valid, "checks": checks}

func start_mission_simulation() -> bool:
	var preflight := evaluate_preflight()
	if not preflight["valid"]:
		return false
	var design: Dictionary = launch_plan["spacecraft_design"]
	var resources: Dictionary = design["resources"]
	var mission: Dictionary = launch_plan["mission"]
	var total_days := maxi(1, int(launch_plan["summary"].get("duration_days", mission.get("duration_days", 1))))
	var stage_span_days := maxi(1, ceili(float(total_days) / 30.0))
	mission_simulation = {
		"active": true, "complete": false, "elapsed_days": 0, "total_days": total_days,
		"stage_span_days": stage_span_days,
		"speed": 1, "phase_index": 0, "energy_wh": float(resources.get("battery_capacity_wh", 0)),
		"energy_capacity_wh": maxi(1, int(resources.get("battery_capacity_wh", 0))),
		"energy_percent": 100.0, "energy_generated_wh": 0.0, "energy_consumed_wh": 0.0,
		"data_collected_gb": 0.0, "data_transmitted_gb": 0.0,
		"science_target_gb": maxf(1.0, float(mission.get("data_requirement_gb_day", 1)) * total_days * 0.65),
		"comms_weighted_pct": 0.0, "comms_days": 0.0,
		"event_flags": {}, "events": [], "successes": []
	}
	mission_report.clear()
	return true

func set_simulation_speed(speed: int) -> void:
	if mission_simulation.is_empty():
		return
	mission_simulation["speed"] = clampi(speed, 1, 10)

func advance_mission_simulation() -> Dictionary:
	if mission_simulation.is_empty() or not mission_simulation.get("active", false):
		return mission_simulation.duplicate(true)
	var state := mission_simulation
	var plan: Dictionary = launch_plan
	var design: Dictionary = plan["spacecraft_design"]
	var resources: Dictionary = design["resources"]
	var orbit: Dictionary = plan["orbit"]
	var total_days: int = state["total_days"]
	var interval_days := maxi(1, ceili(float(total_days) / 40.0))
	var step_days := mini(total_days - int(state["elapsed_days"]), interval_days * int(state["speed"]))
	var previous_day: int = state["elapsed_days"]
	var elapsed_day := previous_day + step_days
	var progress := float(elapsed_day) / float(total_days)
	state["elapsed_days"] = elapsed_day
	var events: Array = state["events"]
	var event_flags: Dictionary = state["event_flags"]
	var components: Array = design.get("components", [])
	var generation := float(resources.get("power_generation_w", 0))
	var load_w := float(resources.get("power_load_w", 0))
	var solar_factor := 0.90
	match str(plan["orbit_id"]):
		"mars": solar_factor = 0.72
		"deep_space": solar_factor = 0.65
		"lunar": solar_factor = 0.86
	var storm_start := ceili(float(total_days) * 0.45)
	var storm_end := storm_start + maxi(1, ceili(float(total_days) * 0.08))
	var storm_days := maxi(0, mini(elapsed_day, storm_end) - maxi(previous_day, storm_start))
	if storm_days > 0 and generation > 0.0 and not event_flags.get("solar_storm", false):
		event_flags["solar_storm"] = true
		events.append("SOLAR WEATHER: panel output temporarily reduced.")
	var generated_wh := generation * solar_factor * 24.0 * (float(step_days - storm_days) + float(storm_days) * 0.32)
	var consumed_wh := load_w * 24.0 * step_days
	state["energy_generated_wh"] = float(state["energy_generated_wh"]) + generated_wh
	state["energy_consumed_wh"] = float(state["energy_consumed_wh"]) + consumed_wh
	var battery_capacity := float(state["energy_capacity_wh"])
	state["energy_wh"] = clampf(float(state["energy_wh"]) + generated_wh - consumed_wh, 0.0, battery_capacity)
	state["energy_percent"] = state["energy_wh"] / battery_capacity * 100.0
	if state["energy_percent"] < 20.0 and not event_flags.get("low_energy", false):
		event_flags["low_energy"] = true
		events.append("LOW POWER: payload operations entered reduced duty cycle.")
	var energy_factor := 1.0 if state["energy_percent"] >= 20.0 else (0.55 if state["energy_percent"] >= 5.0 else 0.2)
	var link_start := ceili(float(total_days) * 0.30)
	var link_end := link_start + maxi(1, ceili(float(total_days) * 0.035))
	var outage_days := maxi(0, mini(elapsed_day, link_end) - maxi(previous_day, link_start)) if float(orbit.get("communication_pct", 0)) < 75.0 else 0
	if outage_days > 0 and not event_flags.get("link_fade", false):
		event_flags["link_fade"] = true
		events.append("LINK FADE: distant ground contact temporarily degraded.")
	var base_comms_quality := float(orbit.get("communication_pct", 0))
	var comms_quality := base_comms_quality * (1.0 - 0.8 * float(outage_days) / float(step_days))
	state["comms_weighted_pct"] = float(state["comms_weighted_pct"]) + comms_quality * step_days
	state["comms_days"] = float(state["comms_days"]) + step_days
	var fault_start := ceili(float(total_days) * 0.64)
	var fault_days := maxi(0, elapsed_day - maxi(previous_day, fault_start)) if float(resources.get("power_net_w", 0)) < 90.0 else 0
	if fault_days > 0 and not event_flags.get("instrument_fault", false):
		event_flags["instrument_fault"] = true
		events.append("INSTRUMENT RESET: science payload output reduced for the remainder of the mission.")
	var science_active := elapsed_day >= int(state["stage_span_days"]) * 3
	if science_active:
		var science_rate := float(resources.get("data_capacity_gb_day", 0)) * float(orbit.get("observation_pct", 0)) / 100.0
		var effective_science_days := float(step_days - fault_days) + float(fault_days) * 0.62
		state["data_collected_gb"] = float(state["data_collected_gb"]) + science_rate * energy_factor * effective_science_days
		var comms_active := comms_quality / 100.0 if components.has("communication_antenna") else 0.0
		state["data_transmitted_gb"] = float(state["data_transmitted_gb"]) + science_rate * energy_factor * comms_active * effective_science_days
	if progress >= 0.86 and not event_flags.get("data_downlink", false):
		event_flags["data_downlink"] = true
		state["successes"].append("Prioritized downlink during the final communications window.")
		if comms_quality >= 60.0:
			state["data_transmitted_gb"] = minf(float(state["data_collected_gb"]), float(state["data_transmitted_gb"]) * 1.08)
	state["phase_index"] = _phase_for_elapsed(elapsed_day, total_days, int(state["stage_span_days"]))
	if elapsed_day >= total_days:
		state["active"] = false
		state["complete"] = true
		state["phase_index"] = MISSION_PHASES.size() - 1
		mission_report = _build_mission_report()
		mission_report["mission"] = plan.get("mission", {}).duplicate(true)
		mission_report["completed_at"] = Time.get_datetime_string_from_system(false)
		mission_history.append(mission_report.duplicate(true))
		_save_mission_history()
	return state.duplicate(true)

func _phase_for_elapsed(elapsed_days: int, total_days: int, stage_span_days: int) -> int:
	if elapsed_days >= total_days:
		return MISSION_PHASES.size() - 1
	var downlink_start := maxi(stage_span_days * 3, mini(total_days - 1, floori(float(total_days) * 0.86)))
	if elapsed_days >= downlink_start:
		return 4
	if elapsed_days >= stage_span_days * 3:
		return 3
	if elapsed_days >= stage_span_days * 2:
		return 2
	if elapsed_days >= stage_span_days:
		return 1
	return 0

func _build_mission_report() -> Dictionary:
	var state: Dictionary = mission_simulation
	var plan: Dictionary = launch_plan
	var summary: Dictionary = plan["summary"]
	var science_pct := clampf(float(state["data_collected_gb"]) / float(state["science_target_gb"]) * 100.0, 0.0, 100.0)
	var transmit_target := maxf(1.0, float(state["science_target_gb"]) * float(plan["orbit"].get("communication_pct", 0)) / 100.0)
	var data_pct := clampf(float(state["data_transmitted_gb"]) / transmit_target * 100.0, 0.0, 100.0)
	var energy_score := clampf(float(state["energy_percent"]), 0.0, 100.0)
	var comms_score := float(state["comms_weighted_pct"]) / maxf(1.0, float(state["comms_days"]))
	var score := roundi(science_pct * 0.45 + data_pct * 0.25 + energy_score * 0.20 + comms_score * 0.10)
	var success := science_pct >= 55.0 and data_pct >= 35.0 and score >= 55
	var failures: Array = state["events"].filter(func(event: String) -> bool: return event.begins_with("LOW POWER") or event.begins_with("INSTRUMENT RESET"))
	return {
		"success": success, "score": score, "science_pct": roundi(science_pct),
		"data_collected_gb": roundi(float(state["data_collected_gb"])),
		"data_transmitted_gb": roundi(float(state["data_transmitted_gb"])),
		"data_pct": roundi(data_pct), "energy_pct": roundi(energy_score),
		"communication_pct": roundi(comms_score), "duration_days": int(state["elapsed_days"]),
		"spent_m": int(summary.get("total_cost_m", 0)),
		"remaining_m": int(summary.get("budget_remaining_m", 0)),
		"energy_generated_wh": roundi(float(state.get("energy_generated_wh", 0))),
		"energy_used_wh": roundi(float(state.get("energy_consumed_wh", 0))),
		"events": state["events"].duplicate(), "failures": failures,
		"successes": state["successes"].duplicate(), "simplified_model": "SIMPLIFIED GAME MODEL — NOT A REAL PHYSICS SIMULATION"
	}

func _format_millions(amount_m: int) -> String:
	if amount_m < 0:
		return "-$%dM" % absi(amount_m)
	if amount_m >= 1000:
		return "$%.1fB" % (float(amount_m) / 1000.0)
	return "$%dM" % amount_m

func _save_mission_history() -> void:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(mission_history, "\t"))

func _mass_limit_for(mission_id: String) -> int:
	if mission_id == "sandbox":
		return 10000
	match mission_id:
		"earth_observation": return 700
		"lunar_exploration": return 1000
		"mars_exploration": return 2300
		"deep_space": return 1400
		_: return 700
