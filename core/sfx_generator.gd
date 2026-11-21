class_name SfxGenerator
extends RefCounted
## Procedural low-voiced SFX synthesizer (no external audio assets required).

const MIX_RATE := 44100

static func create_office_door_open() -> AudioStreamWAV:
	const DURATION := 0.38
	var total_samples := int(MIX_RATE * DURATION)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 51042

	var wood_phase := 0.0
	var damp_noise := 0.0

	for i in range(total_samples):
		var t := float(i) / float(MIX_RATE)
		var sample := 0.0

		# 1. "Tik" (t = 0.00s, 15ms handle press click + 4ms damped noise micro-burst)
		if t < 0.015:
			var env := exp(-t * 280.0) * minf(1.0, t / 0.0006)
			sample += (sin(TAU * 680.0 * t) * 0.55 + sin(TAU * 1350.0 * t) * 0.30) * env
			if t < 0.004:
				damp_noise = lerpf(damp_noise, rng.randf_range(-1.0, 1.0), 0.35)
				sample += damp_noise * exp(-t * 600.0) * 0.35

		# 2. "Tak" (t = 0.075s, 22ms latch bolt release clack + frame thump)
		if t >= 0.075 and t < 0.097:
			var dt := t - 0.075
			var env := exp(-dt * 200.0) * minf(1.0, dt / 0.0008)
			var clack := sin(TAU * 420.0 * dt) * 0.65 + sin(TAU * 890.0 * dt) * 0.35
			var thump := sin(TAU * 145.0 * dt) * 0.45
			sample += (clack + thump) * env

		# 3. Subtle unseal settle (t = 0.14s - 0.35s, damped 78 -> 54 Hz wood thud, zero noise)
		if t >= 0.14 and t < 0.35:
			var dt := t - 0.14
			var u := dt / 0.21
			var freq := lerpf(78.0, 54.0, u)
			wood_phase += TAU * freq / float(MIX_RATE)
			var env := exp(-dt * 14.0) * minf(1.0, dt / 0.006)
			sample += sin(wood_phase) * env * 0.15

		var pcm := clampi(int(round(clampf(sample, -1.0, 1.0) * 32767.0)), -32768, 32767)
		data.encode_s16(i * 2, pcm)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
