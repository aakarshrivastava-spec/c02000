extends RefCounted
## Campaign data: destinations, equipment, levels. Generated from the web version (src/campaign/*.js).
## "science" = established planetary facts. "env" = GAME SIMULATION severities (0..1) used by the damage engine.

const FACTORS := [
	{
		"id": "heat",
		"name": "Temperature (heat)",
		"unit": ""
	},
	{
		"id": "cold",
		"name": "Temperature (cold)",
		"unit": ""
	},
	{
		"id": "pressure",
		"name": "Atmospheric pressure",
		"unit": ""
	},
	{
		"id": "corrosion",
		"name": "Atmospheric composition",
		"unit": ""
	},
	{
		"id": "gravity",
		"name": "Gravity",
		"unit": ""
	},
	{
		"id": "radiation",
		"name": "Radiation",
		"unit": ""
	},
	{
		"id": "dust",
		"name": "Dust and surface particles",
		"unit": ""
	},
	{
		"id": "geology",
		"name": "Geological activity",
		"unit": ""
	},
	{
		"id": "terrain",
		"name": "Surface terrain",
		"unit": ""
	},
	{
		"id": "wind",
		"name": "Wind",
		"unit": ""
	},
	{
		"id": "solar",
		"name": "Solar energy availability",
		"unit": ""
	},
	{
		"id": "particles",
		"name": "Ring and debris particles",
		"unit": ""
	}
]

const HAZARDS := {
	"thermalHeat": {
		"name": "Heat load",
		"factor": "heat",
		"comps": [
			"thermal",
			"instruments",
			"power"
		],
		"protect": "heatTol",
		"rate": 18,
		"why": "Surface heat is higher than the thermal protection was designed for."
	},
	"thermalCold": {
		"name": "Extreme cold",
		"factor": "cold",
		"comps": [
			"power",
			"thermal",
			"instruments"
		],
		"protect": "coldTol",
		"rate": 12,
		"why": "Cold is draining the batteries and stiffening mechanisms beyond the heaters' design limit."
	},
	"pressure": {
		"name": "Crushing pressure",
		"factor": "pressure",
		"comps": [
			"structure",
			"landing"
		],
		"protect": "pressTol",
		"rate": 18,
		"why": "Atmospheric pressure is greater than the pressure vessel rating."
	},
	"corrosion": {
		"name": "Corrosive atmosphere",
		"factor": "corrosion",
		"comps": [
			"instruments",
			"solar",
			"comms"
		],
		"protect": "corrTol",
		"rate": 10,
		"why": "Atmospheric chemistry is attacking unprotected external equipment."
	},
	"radiation": {
		"name": "Radiation dose",
		"factor": "radiation",
		"comps": [
			"instruments",
			"nav",
			"comms",
			"power"
		],
		"protect": "radTol",
		"rate": 11,
		"why": "Radiation dose rate is above what the shielding can stop. Electronics degrade."
	},
	"dust": {
		"name": "Dust accumulation",
		"factor": "dust",
		"comps": [],
		"protect": "dustMit",
		"rate": 0,
		"why": "Fine dust settles on panels and sensors.",
		"special": "dust"
	},
	"terrain": {
		"name": "Rough terrain",
		"factor": "terrain",
		"comps": [
			"rover"
		],
		"protect": "wheelTol",
		"rate": 9,
		"why": "Sharp rocks and uneven ground stress wheels and suspension while driving.",
		"onlyWhen": "driving"
	},
	"geology": {
		"name": "Geological activity",
		"factor": "geology",
		"comps": [
			"structure",
			"instruments",
			"solar"
		],
		"protect": "geoTol",
		"rate": 8,
		"why": "Active geology (eruptions, plumes or fresh deposits) is coating or shaking surface equipment."
	},
	"wind": {
		"name": "Wind loading",
		"factor": "wind",
		"comps": [
			"structure",
			"nav"
		],
		"protect": "windTol",
		"rate": 8,
		"why": "Strong winds buffet the vehicle beyond its design load."
	},
	"particles": {
		"name": "Particle impacts",
		"factor": "particles",
		"comps": [
			"structure",
			"solar",
			"comms"
		],
		"protect": "impactTol",
		"rate": 12,
		"why": "Small particles strike the spacecraft faster than the shielding can absorb.",
		"onlyWhen": "orbit"
	}
}

const DESTINATIONS := {
	"earth": {
		"id": "earth",
		"name": "Earth",
		"title": "THE REFERENCE WORLD",
		"type": "surface",
		"body": "earth",
		"parent": null,
		"cycleName": "day",
		"cycles": 8,
		"color": "#4da6ff",
		"science": {
			"gravity": "9.8 m/s²",
			"temperature": "about −89 °C to +57 °C (recorded extremes)",
			"pressure": "1 bar at sea level",
			"atmosphere": "78% nitrogen, 21% oxygen",
			"sunlight": "1,361 W/m² at the top of the atmosphere (the reference value)",
			"lightTime": "instant (local mission control)",
			"notes": [
				"About 71% of the surface is covered by ocean.",
				"Weather changes quickly and can delay landings and launches."
			]
		},
		"env": {
			"heat": {
				"sev": 0.1,
				"shown": "15 °C average"
			},
			"cold": {
				"sev": 0.1,
				"shown": "15 °C average"
			},
			"pressure": {
				"sev": 0.05,
				"shown": "1 bar"
			},
			"corrosion": {
				"sev": 0.05,
				"shown": "Nitrogen / oxygen, humid"
			},
			"gravity": {
				"sev": 0.6,
				"shown": "9.8 m/s²"
			},
			"radiation": {
				"sev": 0.05,
				"shown": "Very low (magnetic field and atmosphere)"
			},
			"dust": {
				"sev": 0.1,
				"shown": "Low"
			},
			"geology": {
				"sev": 0.05,
				"shown": "Low at the test range"
			},
			"terrain": {
				"sev": 0.35,
				"shown": "Mountains, valleys, ocean"
			},
			"wind": {
				"sev": 0.35,
				"shown": "Variable weather"
			},
			"solar": {
				"sev": 1,
				"shown": "100% (reference)"
			},
			"particles": null
		},
		"na": {
			"particles": "No ring system."
		},
		"hazards": [
			"terrain",
			"wind"
		],
		"insertFuel": 10,
		"c3": 1,
		"cruise": 0,
		"objectives": [
			{
				"id": "map",
				"name": "Map the landing test range",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "weather",
				"name": "Record weather for a landing window",
				"tag": "atmosphere",
				"units": 2,
				"mode": "surface",
				"primary": false
			},
			{
				"id": "terrain",
				"name": "Drive to a valley test site",
				"tag": "drive",
				"units": 2,
				"mode": "drive",
				"primary": false
			}
		],
		"landingSites": [
			{
				"id": "plain",
				"name": "Desert plain",
				"rough": 0.2,
				"sci": 1,
				"note": "flat, dry and safe"
			},
			{
				"id": "valley",
				"name": "Mountain valley",
				"rough": 0.55,
				"sci": 1.3,
				"note": "interesting geology, steep slopes"
			},
			{
				"id": "ocean",
				"name": "Open ocean",
				"rough": 1.4,
				"sci": 0.3,
				"water": true,
				"note": "not suitable for a lander"
			}
		]
	},
	"mercury": {
		"id": "mercury",
		"name": "Mercury",
		"title": "THE EXTREME FRONTIER",
		"type": "surface",
		"body": "mercury",
		"parent": null,
		"cycleName": "two-week period",
		"cycles": 10,
		"color": "#9a928a",
		"science": {
			"gravity": "3.7 m/s² (38% of Earth)",
			"temperature": "about +430 °C in daytime to −180 °C at night",
			"pressure": "almost none (a thin exosphere)",
			"atmosphere": "Exosphere of sodium, potassium, oxygen and helium atoms",
			"sunlight": "about 4.6 to 10.6 times the sunlight at Earth",
			"lightTime": "4 to 12 minutes one way",
			"notes": [
				"One solar day on Mercury lasts 176 Earth days.",
				"MESSENGER (2011–2015) used a ceramic-cloth sunshade to survive."
			]
		},
		"env": {
			"heat": {
				"sev": 0.95,
				"shown": "+430 °C (dayside)"
			},
			"cold": {
				"sev": 0.75,
				"shown": "−180 °C (nightside)"
			},
			"pressure": null,
			"corrosion": null,
			"gravity": {
				"sev": 0.3,
				"shown": "3.7 m/s²"
			},
			"radiation": {
				"sev": 0.55,
				"shown": "High solar radiation, weak magnetic field"
			},
			"dust": {
				"sev": 0.2,
				"shown": "Fine regolith, no wind to lift it"
			},
			"geology": {
				"sev": 0.05,
				"shown": "Inactive (old cratered crust)"
			},
			"terrain": {
				"sev": 0.75,
				"shown": "Heavily cratered"
			},
			"wind": null,
			"solar": {
				"sev": 1,
				"shown": "~670% of Earth (too much, causes heating)"
			},
			"particles": null
		},
		"na": {
			"pressure": "Essentially no atmosphere (only an exosphere).",
			"corrosion": "No atmosphere to corrode equipment.",
			"wind": "No meaningful atmosphere, so no wind.",
			"particles": "No ring system."
		},
		"hazards": [
			"thermalHeat",
			"thermalCold",
			"radiation",
			"terrain"
		],
		"dayNight": true,
		"insertFuel": 34,
		"c3": 0.3,
		"cruise": 3,
		"objectives": [
			{
				"id": "thermal",
				"name": "Measure surface temperature across day and night",
				"tag": "thermal",
				"units": 3,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "crater",
				"name": "Image the crater floor",
				"tag": "imaging",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "comp",
				"name": "Analyse surface composition",
				"tag": "composition",
				"units": 2,
				"mode": "surface",
				"primary": false
			},
			{
				"id": "rim",
				"name": "Drive to the crater rim",
				"tag": "drive",
				"units": 2,
				"mode": "drive",
				"primary": false
			}
		],
		"landingSites": [
			{
				"id": "terminator",
				"name": "Near the day/night line",
				"rough": 0.45,
				"sci": 1,
				"note": "milder temperatures"
			},
			{
				"id": "crater",
				"name": "Inside a crater",
				"rough": 0.75,
				"sci": 1.35,
				"note": "rough floor, rich science"
			},
			{
				"id": "pole",
				"name": "Shadowed polar crater",
				"rough": 0.6,
				"sci": 1.2,
				"cold": true,
				"note": "ice may exist, very cold"
			}
		]
	},
	"venus": {
		"id": "venus",
		"name": "Venus",
		"title": "THE CRUSHING WORLD",
		"type": "surface",
		"body": "venus",
		"parent": null,
		"cycleName": "15-minute interval",
		"cycles": 8,
		"color": "#e6c88a",
		"science": {
			"gravity": "8.9 m/s² (90% of Earth)",
			"temperature": "about +465 °C at the surface, day and night",
			"pressure": "about 92 bar (like 900 m under the sea)",
			"atmosphere": "96.5% carbon dioxide, 3.5% nitrogen; clouds of sulfuric acid",
			"sunlight": "only a few percent reaches the surface through the clouds",
			"lightTime": "2 to 14 minutes one way",
			"notes": [
				"The longest-lived lander, Venera 13 (1982), lasted 127 minutes.",
				"The surface is mostly volcanic plains and highlands."
			]
		},
		"env": {
			"heat": {
				"sev": 1,
				"shown": "+465 °C"
			},
			"cold": null,
			"pressure": {
				"sev": 1,
				"shown": "92 bar"
			},
			"corrosion": {
				"sev": 0.8,
				"shown": "CO₂ with sulfuric acid clouds"
			},
			"gravity": {
				"sev": 0.55,
				"shown": "8.9 m/s²"
			},
			"radiation": {
				"sev": 0.05,
				"shown": "Low at the surface (thick atmosphere)"
			},
			"dust": {
				"sev": 0.1,
				"shown": "Low"
			},
			"geology": {
				"sev": 0.2,
				"shown": "Volcanic plains (activity uncertain)"
			},
			"terrain": {
				"sev": 0.5,
				"shown": "Volcanic rock, lava plains"
			},
			"wind": {
				"sev": 0.1,
				"shown": "About 1 m/s at the surface"
			},
			"solar": {
				"sev": 0.03,
				"shown": "~3% at surface (thick cloud)"
			},
			"particles": null
		},
		"na": {
			"cold": "The surface is hot everywhere, day and night.",
			"particles": "No ring system."
		},
		"hazards": [
			"thermalHeat",
			"pressure",
			"corrosion",
			"terrain"
		],
		"leaks": true,
		"insertFuel": 22,
		"c3": 0.45,
		"cruise": 2,
		"objectives": [
			{
				"id": "panorama",
				"name": "Take a surface panorama",
				"tag": "imaging",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "rock",
				"name": "Analyse volcanic rock",
				"tag": "composition",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "air",
				"name": "Measure the lower atmosphere",
				"tag": "atmosphere",
				"units": 2,
				"mode": "surface",
				"primary": false
			}
		],
		"landingSites": [
			{
				"id": "plains",
				"name": "Lava plains",
				"rough": 0.35,
				"sci": 1,
				"note": "smooth basalt"
			},
			{
				"id": "tessera",
				"name": "Tessera highlands",
				"rough": 0.8,
				"sci": 1.4,
				"note": "oldest, most folded terrain"
			}
		]
	},
	"mars": {
		"id": "mars",
		"name": "Mars",
		"title": "THE RED PLANET",
		"type": "surface",
		"body": "mars",
		"parent": null,
		"cycleName": "sol",
		"cycles": 12,
		"color": "#c1440e",
		"science": {
			"gravity": "3.7 m/s² (38% of Earth)",
			"temperature": "about −125 °C to +20 °C",
			"pressure": "about 0.006 bar (under 1% of Earth)",
			"atmosphere": "95% carbon dioxide, small amounts of nitrogen and argon",
			"sunlight": "about 43% of the sunlight at Earth",
			"lightTime": "3 to 22 minutes one way",
			"notes": [
				"A sol (Mars day) is 24 h 39 min.",
				"A global dust storm in 2018 ended the Opportunity rover by blocking sunlight.",
				"Curiosity's aluminium wheels were punctured by sharp rocks."
			]
		},
		"env": {
			"heat": {
				"sev": 0.15,
				"shown": "up to +20 °C"
			},
			"cold": {
				"sev": 0.65,
				"shown": "down to −125 °C"
			},
			"pressure": {
				"sev": 0.02,
				"shown": "0.006 bar"
			},
			"corrosion": {
				"sev": 0.1,
				"shown": "CO₂, oxidising soil"
			},
			"gravity": {
				"sev": 0.3,
				"shown": "3.7 m/s²"
			},
			"radiation": {
				"sev": 0.35,
				"shown": "Moderate (thin air, no global magnetic field)"
			},
			"dust": {
				"sev": 0.7,
				"shown": "Widespread fine dust"
			},
			"geology": {
				"sev": 0.05,
				"shown": "Low (rare marsquakes)"
			},
			"terrain": {
				"sev": 0.65,
				"shown": "Rocky, craters"
			},
			"wind": {
				"sev": 0.3,
				"shown": "Thin air: storms lift dust but push weakly"
			},
			"solar": {
				"sev": 0.43,
				"shown": "43% of Earth"
			},
			"particles": null
		},
		"na": {
			"particles": "No ring system."
		},
		"hazards": [
			"dust",
			"thermalCold",
			"terrain",
			"radiation"
		],
		"dustStorms": true,
		"dayNight": true,
		"insertFuel": 20,
		"c3": 0.45,
		"cruise": 2,
		"objectives": [
			{
				"id": "rock",
				"name": "Drill and analyse a rock sample",
				"tag": "sample",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "delta",
				"name": "Drive to the ancient river delta",
				"tag": "drive",
				"units": 3,
				"mode": "drive",
				"primary": true
			},
			{
				"id": "weather",
				"name": "Keep a weather record",
				"tag": "atmosphere",
				"units": 3,
				"mode": "surface",
				"primary": false
			},
			{
				"id": "pano",
				"name": "Image the crater walls",
				"tag": "imaging",
				"units": 2,
				"mode": "surface",
				"primary": false
			}
		],
		"landingSites": [
			{
				"id": "plain",
				"name": "Smooth plain",
				"rough": 0.3,
				"sci": 1,
				"note": "safe, like Opportunity's site"
			},
			{
				"id": "crater",
				"name": "Jezero-style crater",
				"rough": 0.65,
				"sci": 1.35,
				"note": "ancient lake bed, boulder fields"
			}
		]
	},
	"jupiter": {
		"id": "jupiter",
		"name": "Jupiter",
		"title": "THE GAS GIANT",
		"type": "probe",
		"body": "jupiter",
		"parent": null,
		"cycleName": "orbit",
		"cycles": 8,
		"color": "#d9b38c",
		"science": {
			"gravity": "24.8 m/s² at the cloud tops",
			"temperature": "about −110 °C at the cloud tops, rising with depth",
			"pressure": "rises without limit; there is no solid surface",
			"atmosphere": "About 90% hydrogen, 10% helium",
			"sunlight": "about 3.7% of the sunlight at Earth",
			"lightTime": "33 to 53 minutes one way",
			"notes": [
				"The Galileo probe (1995) sent data for 58 minutes down to about 22 bar before it was lost.",
				"Juno protects its electronics inside a titanium radiation vault."
			]
		},
		"env": {
			"heat": {
				"sev": 0.2,
				"shown": "rises with depth"
			},
			"cold": {
				"sev": 0.6,
				"shown": "−110 °C cloud tops"
			},
			"pressure": {
				"sev": 0,
				"shown": "rises with depth (probe only)"
			},
			"corrosion": {
				"sev": 0.05,
				"shown": "H₂ / He, ammonia clouds"
			},
			"gravity": {
				"sev": 1,
				"shown": "24.8 m/s²"
			},
			"radiation": {
				"sev": 1,
				"shown": "Extreme radiation belts"
			},
			"dust": null,
			"geology": null,
			"terrain": null,
			"wind": {
				"sev": 0.8,
				"shown": "Jets over 500 km/h"
			},
			"solar": {
				"sev": 0.037,
				"shown": "3.7% of Earth"
			},
			"particles": {
				"sev": 0.1,
				"shown": "Faint dusty rings"
			}
		},
		"na": {
			"dust": "No surface to collect dust.",
			"geology": "No solid surface.",
			"terrain": "No solid surface: an atmospheric probe is used, not a lander."
		},
		"hazards": [
			"radiation",
			"thermalCold",
			"wind"
		],
		"probe": {
			"levels": [
				[
					0.5,
					-130
				],
				[
					1,
					-110
				],
				[
					2,
					-80
				],
				[
					5,
					-10
				],
				[
					10,
					60
				],
				[
					16,
					110
				],
				[
					22,
					153
				],
				[
					35,
					230
				],
				[
					60,
					330
				]
			],
			"windSev": 0.8,
			"layers": [
				"#d9b38c",
				"#c69568",
				"#a8714c",
				"#7b4b31",
				"#4a2a1b"
			]
		},
		"orbits": [
			{
				"id": "far",
				"name": "Distant orbit",
				"rad": 0.35,
				"sci": 0.7,
				"note": "stays outside the worst radiation"
			},
			{
				"id": "polar",
				"name": "Polar orbit (Juno style)",
				"rad": 0.75,
				"sci": 1.15,
				"note": "dives under the belts, brief intense exposure"
			},
			{
				"id": "low",
				"name": "Low equatorial orbit",
				"rad": 1.35,
				"sci": 1.4,
				"note": "inside the radiation belts"
			}
		],
		"insertFuel": 40,
		"c3": 0.22,
		"cruise": 4,
		"objectives": [
			{
				"id": "probe",
				"name": "Probe: measure the atmosphere below the clouds",
				"tag": "probe",
				"units": 4,
				"mode": "probe",
				"primary": true
			},
			{
				"id": "storm",
				"name": "Observe the Great Red Spot",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "field",
				"name": "Map the magnetic field",
				"tag": "fields",
				"units": 2,
				"mode": "orbit",
				"primary": false
			}
		]
	},
	"saturn": {
		"id": "saturn",
		"name": "Saturn",
		"title": "THE RINGED GIANT",
		"type": "probe",
		"body": "saturn",
		"parent": null,
		"cycleName": "orbit",
		"cycles": 8,
		"color": "#e6d29c",
		"science": {
			"gravity": "10.4 m/s² at the cloud tops",
			"temperature": "about −140 °C at the cloud tops",
			"pressure": "rises with depth; there is no solid surface",
			"atmosphere": "About 96% hydrogen, 3% helium",
			"sunlight": "about 1.1% of the sunlight at Earth",
			"lightTime": "68 to 84 minutes one way",
			"notes": [
				"The rings are mostly water-ice pieces, from dust grains to house-sized blocks.",
				"Cassini flew 22 times between the rings and the planet in 2017."
			]
		},
		"env": {
			"heat": {
				"sev": 0.15,
				"shown": "rises with depth"
			},
			"cold": {
				"sev": 0.7,
				"shown": "−140 °C cloud tops"
			},
			"pressure": {
				"sev": 0,
				"shown": "rises with depth (probe only)"
			},
			"corrosion": {
				"sev": 0.05,
				"shown": "H₂ / He"
			},
			"gravity": {
				"sev": 0.6,
				"shown": "10.4 m/s²"
			},
			"radiation": {
				"sev": 0.3,
				"shown": "Moderate radiation belts"
			},
			"dust": null,
			"geology": null,
			"terrain": null,
			"wind": {
				"sev": 0.85,
				"shown": "Equatorial jets up to 1,800 km/h"
			},
			"solar": {
				"sev": 0.011,
				"shown": "1.1% of Earth"
			},
			"particles": {
				"sev": 0.8,
				"shown": "Icy ring particles"
			}
		},
		"na": {
			"dust": "No surface to collect dust.",
			"geology": "No solid surface.",
			"terrain": "No solid surface: orbital study and an atmospheric probe only."
		},
		"hazards": [
			"particles",
			"thermalCold",
			"radiation",
			"wind"
		],
		"probe": {
			"levels": [
				[
					0.5,
					-160
				],
				[
					1,
					-140
				],
				[
					2,
					-110
				],
				[
					5,
					-50
				],
				[
					10,
					20
				],
				[
					20,
					100
				],
				[
					35,
					180
				],
				[
					60,
					280
				]
			],
			"windSev": 0.85,
			"layers": [
				"#efe0b8",
				"#d9c08a",
				"#b89a62",
				"#8a6f42",
				"#4e3d22"
			]
		},
		"orbits": [
			{
				"id": "outer",
				"name": "Outside the main rings",
				"imp": 0.25,
				"sci": 0.75,
				"note": "safe, distant views"
			},
			{
				"id": "cross",
				"name": "Ring-plane crossings",
				"imp": 0.75,
				"sci": 1.15,
				"note": "passes through the faint outer ring region"
			},
			{
				"id": "gap",
				"name": "Dive through the ring gap (Grand Finale style)",
				"imp": 1.2,
				"sci": 1.45,
				"note": "between the rings and the clouds"
			}
		],
		"insertFuel": 42,
		"c3": 0.18,
		"cruise": 5,
		"objectives": [
			{
				"id": "probe",
				"name": "Probe: measure helium and winds",
				"tag": "probe",
				"units": 4,
				"mode": "probe",
				"primary": true
			},
			{
				"id": "rings",
				"name": "Measure ring particle sizes",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "field",
				"name": "Map the magnetic field",
				"tag": "fields",
				"units": 2,
				"mode": "orbit",
				"primary": false
			}
		]
	},
	"uranus": {
		"id": "uranus",
		"name": "Uranus",
		"title": "THE ICE GIANT",
		"type": "probe",
		"body": "uranus",
		"parent": null,
		"cycleName": "orbit",
		"cycles": 8,
		"color": "#9fe0e6",
		"science": {
			"gravity": "8.7 m/s² at the cloud tops",
			"temperature": "about −195 °C at the 1-bar level; it has the coldest measured planetary atmosphere (about −224 °C)",
			"pressure": "rises with depth; there is no solid surface",
			"atmosphere": "Hydrogen and helium with about 2% methane (gives the blue-green colour)",
			"sunlight": "about 0.27% of the sunlight at Earth",
			"lightTime": "about 2 hours 40 minutes one way",
			"notes": [
				"Uranus is tilted about 98°, so it rolls around the Sun on its side.",
				"Only Voyager 2 has visited, in 1986.",
				"Its magnetic field is tilted about 59° from the spin axis."
			]
		},
		"env": {
			"heat": null,
			"cold": {
				"sev": 1,
				"shown": "−195 °C"
			},
			"pressure": {
				"sev": 0,
				"shown": "rises with depth (probe only)"
			},
			"corrosion": {
				"sev": 0.05,
				"shown": "H₂ / He / CH₄"
			},
			"gravity": {
				"sev": 0.55,
				"shown": "8.7 m/s²"
			},
			"radiation": {
				"sev": 0.25,
				"shown": "Moderate, unusual tilted field"
			},
			"dust": null,
			"geology": null,
			"terrain": null,
			"wind": {
				"sev": 0.7,
				"shown": "Up to about 900 km/h"
			},
			"solar": {
				"sev": 0.0027,
				"shown": "0.27% of Earth"
			},
			"particles": {
				"sev": 0.2,
				"shown": "Narrow dark rings"
			}
		},
		"na": {
			"heat": "No hot environment at the levels a probe can reach in this mission.",
			"dust": "No surface.",
			"geology": "No solid surface.",
			"terrain": "No solid surface: atmospheric probe only."
		},
		"hazards": [
			"thermalCold",
			"wind",
			"radiation"
		],
		"probe": {
			"levels": [
				[
					0.5,
					-205
				],
				[
					1,
					-195
				],
				[
					2,
					-180
				],
				[
					5,
					-150
				],
				[
					10,
					-110
				],
				[
					20,
					-50
				],
				[
					35,
					20
				],
				[
					60,
					110
				]
			],
			"windSev": 0.7,
			"layers": [
				"#bff0f2",
				"#9fe0e6",
				"#79c3cc",
				"#4f9aa6",
				"#2a5f68"
			]
		},
		"orbits": [
			{
				"id": "wide",
				"name": "Wide orbit",
				"rad": 0.3,
				"sci": 0.8,
				"note": "stable, low risk"
			},
			{
				"id": "close",
				"name": "Close polar orbit",
				"rad": 0.7,
				"sci": 1.25,
				"note": "better views of the tilted poles"
			}
		],
		"insertFuel": 44,
		"c3": 0.14,
		"cruise": 6,
		"objectives": [
			{
				"id": "probe",
				"name": "Probe: measure methane and temperature",
				"tag": "probe",
				"units": 4,
				"mode": "probe",
				"primary": true
			},
			{
				"id": "field",
				"name": "Map the tilted magnetic field",
				"tag": "fields",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "img",
				"name": "Image the polar clouds",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": false
			}
		]
	},
	"neptune": {
		"id": "neptune",
		"name": "Neptune",
		"title": "THE DISTANT FRONTIER",
		"type": "probe",
		"body": "neptune",
		"parent": null,
		"cycleName": "orbit",
		"cycles": 8,
		"color": "#3b5fd0",
		"science": {
			"gravity": "11.2 m/s² at the cloud tops",
			"temperature": "about −200 °C at the 1-bar level",
			"pressure": "rises with depth; there is no solid surface",
			"atmosphere": "Hydrogen and helium with methane",
			"sunlight": "about 0.1% of the sunlight at Earth",
			"lightTime": "about 4 hours one way",
			"notes": [
				"Neptune has the fastest winds measured in the Solar System, about 2,000 km/h.",
				"Voyager 2 saw the Great Dark Spot storm in 1989."
			]
		},
		"env": {
			"heat": null,
			"cold": {
				"sev": 1,
				"shown": "−200 °C"
			},
			"pressure": {
				"sev": 0,
				"shown": "rises with depth (probe only)"
			},
			"corrosion": {
				"sev": 0.05,
				"shown": "H₂ / He / CH₄"
			},
			"gravity": {
				"sev": 0.65,
				"shown": "11.2 m/s²"
			},
			"radiation": {
				"sev": 0.2,
				"shown": "Moderate"
			},
			"dust": null,
			"geology": null,
			"terrain": null,
			"wind": {
				"sev": 1,
				"shown": "About 2,000 km/h"
			},
			"solar": {
				"sev": 0.001,
				"shown": "0.1% of Earth"
			},
			"particles": {
				"sev": 0.15,
				"shown": "Faint dusty rings"
			}
		},
		"na": {
			"heat": "No hot environment at the levels a probe can reach in this mission.",
			"dust": "No surface.",
			"geology": "No solid surface.",
			"terrain": "No solid surface: atmospheric probe only."
		},
		"hazards": [
			"thermalCold",
			"wind",
			"radiation"
		],
		"probe": {
			"levels": [
				[
					0.5,
					-210
				],
				[
					1,
					-200
				],
				[
					2,
					-185
				],
				[
					5,
					-150
				],
				[
					10,
					-100
				],
				[
					20,
					-40
				],
				[
					35,
					30
				],
				[
					60,
					120
				]
			],
			"windSev": 1,
			"layers": [
				"#5a7be6",
				"#3b5fd0",
				"#2e4cb4",
				"#203a8c",
				"#122255"
			]
		},
		"orbits": [
			{
				"id": "wide",
				"name": "Wide orbit",
				"rad": 0.3,
				"sci": 0.8,
				"note": "stable, low risk"
			},
			{
				"id": "triton",
				"name": "Orbit with Triton flybys",
				"rad": 0.45,
				"sci": 1.2,
				"note": "extra science, more manoeuvres"
			}
		],
		"insertFuel": 46,
		"c3": 0.12,
		"cruise": 7,
		"objectives": [
			{
				"id": "probe",
				"name": "Probe: measure the winds",
				"tag": "probe",
				"units": 4,
				"mode": "probe",
				"primary": true
			},
			{
				"id": "storm",
				"name": "Track a dark storm",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "field",
				"name": "Map the magnetic field",
				"tag": "fields",
				"units": 2,
				"mode": "orbit",
				"primary": false
			}
		]
	},
	"europa": {
		"id": "europa",
		"name": "Europa",
		"title": "THE FROZEN OCEAN WORLD",
		"type": "surface",
		"body": "jupiter",
		"parent": "Jupiter",
		"cycleName": "Earth day",
		"cycles": 10,
		"color": "#e9dfcf",
		"science": {
			"gravity": "1.3 m/s² (13% of Earth)",
			"temperature": "about −160 °C at the equator, colder at the poles",
			"pressure": "almost none",
			"atmosphere": "Extremely thin oxygen exosphere",
			"sunlight": "about 3.7% of the sunlight at Earth",
			"lightTime": "33 to 53 minutes one way",
			"notes": [
				"Strong evidence points to a salty liquid-water ocean under the ice shell.",
				"The surface receives intense radiation from Jupiter's magnetosphere.",
				"Europa Clipper launched in 2024 to study it with many flybys."
			]
		},
		"env": {
			"heat": null,
			"cold": {
				"sev": 0.85,
				"shown": "−160 °C"
			},
			"pressure": null,
			"corrosion": null,
			"gravity": {
				"sev": 0.1,
				"shown": "1.3 m/s²"
			},
			"radiation": {
				"sev": 0.9,
				"shown": "Very high (Jupiter's belts)"
			},
			"dust": {
				"sev": 0.1,
				"shown": "Ice grains"
			},
			"geology": {
				"sev": 0.2,
				"shown": "Young, fractured ice"
			},
			"terrain": {
				"sev": 0.7,
				"shown": "Ridges and fractures"
			},
			"wind": null,
			"solar": {
				"sev": 0.037,
				"shown": "3.7% of Earth"
			},
			"particles": null
		},
		"na": {
			"heat": "Never hot.",
			"pressure": "No meaningful atmosphere.",
			"corrosion": "No meaningful atmosphere.",
			"wind": "No meaningful atmosphere, so no wind.",
			"particles": "Not inside a ring system."
		},
		"hazards": [
			"thermalCold",
			"radiation",
			"terrain",
			"geology"
		],
		"fractures": true,
		"insertFuel": 48,
		"c3": 0.22,
		"cruise": 4,
		"objectives": [
			{
				"id": "ice",
				"name": "Sound the ice shell with radar",
				"tag": "subsurface",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "salt",
				"name": "Analyse surface salts",
				"tag": "sample",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "ridge",
				"name": "Drive to a double ridge",
				"tag": "drive",
				"units": 2,
				"mode": "drive",
				"primary": false
			},
			{
				"id": "rad",
				"name": "Measure the radiation environment",
				"tag": "radiation",
				"units": 2,
				"mode": "surface",
				"primary": false
			}
		],
		"landingSites": [
			{
				"id": "smooth",
				"name": "Smooth ice plain",
				"rough": 0.35,
				"sci": 1,
				"note": "fewer ridges"
			},
			{
				"id": "chaos",
				"name": "Chaos terrain",
				"rough": 0.8,
				"sci": 1.4,
				"note": "broken ice blocks, may link to the ocean"
			}
		]
	},
	"titan": {
		"id": "titan",
		"name": "Titan",
		"title": "THE METHANE WORLD",
		"type": "surface",
		"body": "saturn",
		"parent": "Saturn",
		"cycleName": "Earth day",
		"cycles": 10,
		"color": "#d79a4a",
		"science": {
			"gravity": "1.35 m/s² (14% of Earth)",
			"temperature": "about −179 °C",
			"pressure": "about 1.5 bar (50% more than Earth)",
			"atmosphere": "About 95% nitrogen, around 5% methane near the surface, thick orange organic haze",
			"sunlight": "about 1% of Earth's, and the haze blocks much of that",
			"lightTime": "68 to 84 minutes one way",
			"notes": [
				"Titan has lakes and seas of liquid methane and ethane, such as Kraken Mare.",
				"The Huygens probe landed in 2005 and sent data from the surface for about 72 minutes.",
				"NASA's Dragonfly rotorcraft is planned to fly there, powered by a nuclear battery."
			]
		},
		"env": {
			"heat": null,
			"cold": {
				"sev": 0.9,
				"shown": "−179 °C"
			},
			"pressure": {
				"sev": 0.08,
				"shown": "1.5 bar"
			},
			"corrosion": {
				"sev": 0.35,
				"shown": "N₂ with methane; hydrocarbon liquids"
			},
			"gravity": {
				"sev": 0.1,
				"shown": "1.35 m/s²"
			},
			"radiation": {
				"sev": 0.05,
				"shown": "Low (thick atmosphere)"
			},
			"dust": {
				"sev": 0.2,
				"shown": "Organic sand dunes"
			},
			"geology": {
				"sev": 0.1,
				"shown": "Possible cryovolcanism (uncertain)"
			},
			"terrain": {
				"sev": 0.5,
				"shown": "Dunes, pebbles, lakes"
			},
			"wind": {
				"sev": 0.2,
				"shown": "Gentle at the surface"
			},
			"solar": {
				"sev": 0.005,
				"shown": "~0.5% after haze"
			},
			"particles": null
		},
		"na": {
			"heat": "Never hot.",
			"particles": "Not inside the main rings."
		},
		"hazards": [
			"thermalCold",
			"corrosion",
			"terrain",
			"wind"
		],
		"lakes": true,
		"allowsRotor": true,
		"insertFuel": 44,
		"c3": 0.18,
		"cruise": 5,
		"objectives": [
			{
				"id": "organics",
				"name": "Analyse organic sand",
				"tag": "sample",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "lake",
				"name": "Reach a methane lake shore",
				"tag": "drive",
				"units": 3,
				"mode": "drive",
				"primary": true
			},
			{
				"id": "haze",
				"name": "Measure the hazy atmosphere",
				"tag": "atmosphere",
				"units": 2,
				"mode": "surface",
				"primary": false
			}
		],
		"landingSites": [
			{
				"id": "dunes",
				"name": "Equatorial dunes",
				"rough": 0.35,
				"sci": 1,
				"note": "like Shangri-La, where Dragonfly will go"
			},
			{
				"id": "lake",
				"name": "Lake shore",
				"rough": 0.55,
				"sci": 1.35,
				"note": "close to the liquid methane, softer ground"
			},
			{
				"id": "sea",
				"name": "On the methane sea",
				"rough": 1.3,
				"sci": 0.5,
				"liquid": true,
				"note": "a lander is not designed to float"
			}
		]
	},
	"io": {
		"id": "io",
		"name": "Io",
		"title": "THE VOLCANIC MOON",
		"type": "surface",
		"body": "jupiter",
		"parent": "Jupiter",
		"cycleName": "Earth day",
		"cycles": 8,
		"color": "#e8c74a",
		"science": {
			"gravity": "1.8 m/s² (18% of Earth)",
			"temperature": "about −130 °C on average, but lava reaches over 1,200 °C",
			"pressure": "almost none (thin, patchy sulfur dioxide)",
			"atmosphere": "Thin sulfur dioxide that freezes and returns",
			"sunlight": "about 3.7% of the sunlight at Earth",
			"lightTime": "33 to 53 minutes one way",
			"notes": [
				"Io is the most volcanically active body known, with hundreds of active volcanoes.",
				"Tidal heating from Jupiter keeps the inside hot.",
				"Io sits inside an intense ring of charged particles (the Io plasma torus)."
			]
		},
		"env": {
			"heat": {
				"sev": 0.35,
				"shown": "local lava hot spots"
			},
			"cold": {
				"sev": 0.7,
				"shown": "−130 °C average"
			},
			"pressure": null,
			"corrosion": {
				"sev": 0.25,
				"shown": "Sulfur dioxide frost"
			},
			"gravity": {
				"sev": 0.15,
				"shown": "1.8 m/s²"
			},
			"radiation": {
				"sev": 1,
				"shown": "Extreme (Io plasma torus)"
			},
			"dust": {
				"sev": 0.4,
				"shown": "Volcanic fallout"
			},
			"geology": {
				"sev": 1,
				"shown": "Constant eruptions"
			},
			"terrain": {
				"sev": 0.6,
				"shown": "Lava flows, calderas"
			},
			"wind": null,
			"solar": {
				"sev": 0.037,
				"shown": "3.7% of Earth"
			},
			"particles": null
		},
		"na": {
			"pressure": "Atmosphere is far too thin to matter.",
			"wind": "No meaningful atmosphere, so no wind.",
			"particles": "Not inside a ring system."
		},
		"hazards": [
			"radiation",
			"geology",
			"thermalCold",
			"thermalHeat",
			"terrain"
		],
		"volcanic": true,
		"insertFuel": 46,
		"c3": 0.22,
		"cruise": 4,
		"objectives": [
			{
				"id": "plume",
				"name": "Image an active eruption",
				"tag": "imaging",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "heat",
				"name": "Map lava temperatures",
				"tag": "thermal",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "sulfur",
				"name": "Analyse sulfur deposits",
				"tag": "composition",
				"units": 2,
				"mode": "surface",
				"primary": false
			}
		],
		"landingSites": [
			{
				"id": "plain",
				"name": "Old sulfur plain",
				"rough": 0.4,
				"sci": 1,
				"note": "far from active vents"
			},
			{
				"id": "patera",
				"name": "Near a volcanic caldera",
				"rough": 0.7,
				"sci": 1.4,
				"note": "fresh lava, frequent fallout"
			}
		]
	},
	"enceladus": {
		"id": "enceladus",
		"name": "Enceladus",
		"title": "THE ICE MOON",
		"type": "surface",
		"body": "saturn",
		"parent": "Saturn",
		"cycleName": "Earth day",
		"cycles": 10,
		"color": "#f2f8ff",
		"science": {
			"gravity": "0.11 m/s² (about 1% of Earth)",
			"temperature": "about −200 °C",
			"pressure": "almost none",
			"atmosphere": "Water vapour near the south-pole plumes only",
			"sunlight": "about 1.1% of the sunlight at Earth",
			"lightTime": "68 to 84 minutes one way",
			"notes": [
				"Jets of water vapour and ice spray from cracks called \"tiger stripes\".",
				"Cassini flew through the plumes and found salts, organic molecules and hydrogen.",
				"It reflects about 80% or more of the sunlight that hits it, one of the brightest surfaces known."
			]
		},
		"env": {
			"heat": null,
			"cold": {
				"sev": 1,
				"shown": "−200 °C"
			},
			"pressure": null,
			"corrosion": null,
			"gravity": {
				"sev": 0.02,
				"shown": "0.11 m/s² (very weak)"
			},
			"radiation": {
				"sev": 0.15,
				"shown": "Low to moderate"
			},
			"dust": {
				"sev": 0.45,
				"shown": "Plume ice grains falling back"
			},
			"geology": {
				"sev": 0.6,
				"shown": "Active water-ice plumes"
			},
			"terrain": {
				"sev": 0.55,
				"shown": "Ice ridges and cracks"
			},
			"wind": null,
			"solar": {
				"sev": 0.011,
				"shown": "1.1% of Earth"
			},
			"particles": null
		},
		"na": {
			"heat": "Never hot.",
			"pressure": "No meaningful atmosphere.",
			"corrosion": "No meaningful atmosphere.",
			"wind": "No meaningful atmosphere, so no wind.",
			"particles": "Orbits within Saturn's faint E ring, which the plumes feed; not a hazard at the surface in this mission."
		},
		"hazards": [
			"thermalCold",
			"geology",
			"terrain",
			"dust"
		],
		"plumes": true,
		"lowG": true,
		"insertFuel": 46,
		"c3": 0.18,
		"cruise": 5,
		"objectives": [
			{
				"id": "plume",
				"name": "Collect and analyse plume material",
				"tag": "plume",
				"units": 3,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "stripe",
				"name": "Drive to a tiger stripe",
				"tag": "drive",
				"units": 2,
				"mode": "drive",
				"primary": false
			},
			{
				"id": "img",
				"name": "Image the jets",
				"tag": "imaging",
				"units": 2,
				"mode": "surface",
				"primary": true
			}
		],
		"landingSites": [
			{
				"id": "plain",
				"name": "Cratered plain",
				"rough": 0.35,
				"sci": 1,
				"note": "away from the plumes"
			},
			{
				"id": "south",
				"name": "South polar terrain",
				"rough": 0.7,
				"sci": 1.45,
				"note": "next to the tiger stripes"
			}
		]
	}
}

const COMPONENTS := [
	{
		"id": "structure",
		"name": "Structural Integrity",
		"short": "Structure",
		"effect": "Holds the spacecraft together. Low structure makes every other kind of damage worse. At 0% the vehicle is lost."
	},
	{
		"id": "thermal",
		"name": "Thermal Protection",
		"short": "Thermal",
		"effect": "Keeps electronics inside their safe temperature range. When it weakens, heat and cold damage spreads to other systems."
	},
	{
		"id": "power",
		"name": "Power Systems",
		"short": "Power",
		"effect": "Batteries and power control. Low power systems store less energy."
	},
	{
		"id": "solar",
		"name": "Solar Panels",
		"short": "Solar",
		"effect": "Generate electricity from sunlight. Damage and dust both reduce output. Not used if the spacecraft runs on a nuclear (RTG) source."
	},
	{
		"id": "comms",
		"name": "Communication Systems",
		"short": "Comms",
		"effect": "Send data home. Weak comms send less data each cycle; at 0% only a backup antenna can reach Earth."
	},
	{
		"id": "nav",
		"name": "Navigation Systems",
		"short": "Navigation",
		"effect": "Star trackers and guidance. Weak navigation wastes fuel on corrections and makes landings and drives less accurate."
	},
	{
		"id": "instruments",
		"name": "Scientific Instruments",
		"short": "Instruments",
		"effect": "Collect the science. Weak instruments return less data; below 20% they stop working unless a backup is carried."
	},
	{
		"id": "landing",
		"name": "Landing Equipment",
		"short": "Landing",
		"effect": "Legs, engines and hazard sensors used during touchdown. A damaged lander may sit tilted, which reduces power and science.",
		"surfaceOnly": true
	},
	{
		"id": "rover",
		"name": "Rover Mobility",
		"short": "Rover",
		"effect": "Wheels, suspension and drive motors. At 0% the rover cannot move, so drive objectives must change.",
		"roverOnly": true
	}
]

const EQUIPMENT := [
	{
		"id": "thermal",
		"name": "Thermal protection",
		"options": [
			{
				"id": "std",
				"name": "Standard blankets",
				"mass": 40,
				"cost": 10,
				"stats": {
					"heatTol": 0.35,
					"coldTol": 0.4
				},
				"desc": "Multi-layer insulation. Fine for Earth and Mars daytime."
			},
			{
				"id": "hot",
				"name": "Heat-shielded (sunshade + insulation)",
				"mass": 120,
				"cost": 30,
				"stats": {
					"heatTol": 0.85,
					"coldTol": 0.35
				},
				"desc": "Ceramic sunshade and thick insulation, like MESSENGER. For hot worlds."
			},
			{
				"id": "cryo",
				"name": "Cold-rated (heaters + radioisotope heater units)",
				"mass": 90,
				"cost": 25,
				"stats": {
					"heatTol": 0.3,
					"coldTol": 0.9
				},
				"desc": "Keeps electronics warm in deep cold."
			},
			{
				"id": "dual",
				"name": "Dual-range thermal system",
				"mass": 190,
				"cost": 48,
				"stats": {
					"heatTol": 0.8,
					"coldTol": 0.85
				},
				"desc": "Handles both extremes. Heavy and expensive."
			},
			{
				"id": "adaptive",
				"name": "Adaptive thermal system (louvres + heat pipes)",
				"mass": 135,
				"cost": 44,
				"stats": {
					"heatTol": 0.9,
					"coldTol": 0.9
				},
				"desc": "Reward component. Handles both extremes at lower mass than the dual-range system.",
				"unlock": 4
			}
		]
	},
	{
		"id": "structure",
		"name": "Structure",
		"options": [
			{
				"id": "std",
				"name": "Standard frame",
				"mass": 200,
				"cost": 20,
				"stats": {
					"pressTol": 0.1,
					"impactTol": 0.3,
					"windTol": 0.45,
					"geoTol": 0.35
				},
				"desc": "Aluminium honeycomb."
			},
			{
				"id": "whipple",
				"name": "Frame + Whipple debris shield",
				"mass": 260,
				"cost": 32,
				"stats": {
					"pressTol": 0.1,
					"impactTol": 0.8,
					"windTol": 0.5,
					"geoTol": 0.5
				},
				"desc": "Layered bumper shields stop small particles."
			},
			{
				"id": "pressure",
				"name": "Pressure vessel (titanium sphere)",
				"mass": 420,
				"cost": 55,
				"stats": {
					"pressTol": 0.92,
					"impactTol": 0.45,
					"windTol": 0.8,
					"geoTol": 0.55
				},
				"desc": "Venera-style sphere for crushing pressure."
			}
		]
	},
	{
		"id": "radiation",
		"name": "Radiation shielding",
		"options": [
			{
				"id": "none",
				"name": "Minimal",
				"mass": 0,
				"cost": 0,
				"stats": {
					"radTol": 0.15
				},
				"desc": "Enough for low Earth orbit."
			},
			{
				"id": "std",
				"name": "Rad-tolerant electronics",
				"mass": 30,
				"cost": 18,
				"stats": {
					"radTol": 0.5
				},
				"desc": "Good for Mars and Mercury."
			},
			{
				"id": "vault",
				"name": "Titanium radiation vault",
				"mass": 180,
				"cost": 45,
				"stats": {
					"radTol": 0.88
				},
				"desc": "Juno-style vault for the Jovian system."
			}
		]
	},
	{
		"id": "power",
		"name": "Power source",
		"options": [
			{
				"id": "solar",
				"name": "Solar arrays + battery",
				"mass": 90,
				"cost": 18,
				"stats": {
					"gen": "solar",
					"panel": 1,
					"battery": 45
				},
				"desc": "Free energy from sunlight. Weak far from the Sun or under dust."
			},
			{
				"id": "solarXL",
				"name": "Large arrays + big battery",
				"mass": 170,
				"cost": 30,
				"stats": {
					"gen": "solar",
					"panel": 1.9,
					"battery": 70
				},
				"desc": "Bigger panels collect more light. Still suffers from dust."
			},
			{
				"id": "batt",
				"name": "High-capacity primary batteries",
				"mass": 110,
				"cost": 10,
				"stats": {
					"gen": "none",
					"battery": 170
				},
				"desc": "No power generation at all. Enough for a few hours, like Venera and Huygens."
			},
			{
				"id": "rtg",
				"name": "Radioisotope generator (RTG)",
				"mass": 60,
				"cost": 75,
				"stats": {
					"gen": "rtg",
					"rtg": 12,
					"battery": 55
				},
				"desc": "Steady power anywhere, day or night, dust or not. Expensive."
			}
		]
	},
	{
		"id": "dust",
		"name": "Dust mitigation",
		"options": [
			{
				"id": "none",
				"name": "None",
				"mass": 0,
				"cost": 0,
				"stats": {
					"dustMit": 0
				},
				"desc": ""
			},
			{
				"id": "mitig",
				"name": "Panel tilt + sealed joints",
				"mass": 15,
				"cost": 8,
				"stats": {
					"dustMit": 0.6
				},
				"desc": "Slows dust build-up and allows panel cleaning."
			}
		]
	},
	{
		"id": "coating",
		"name": "Protective coating",
		"options": [
			{
				"id": "none",
				"name": "None",
				"mass": 0,
				"cost": 0,
				"stats": {
					"corrTol": 0.1
				},
				"desc": ""
			},
			{
				"id": "acid",
				"name": "Acid- and chemical-resistant coating",
				"mass": 25,
				"cost": 12,
				"stats": {
					"corrTol": 0.85
				},
				"desc": "Protects external parts from corrosive or reactive chemistry."
			}
		]
	},
	{
		"id": "landing",
		"name": "Landing system",
		"surfaceOnly": true,
		"options": [
			{
				"id": "legs",
				"name": "Legs + radar altimeter",
				"mass": 140,
				"cost": 20,
				"stats": {
					"hazardAvoid": 0.35
				},
				"desc": "Basic touchdown."
			},
			{
				"id": "trn",
				"name": "Terrain-relative navigation",
				"mass": 165,
				"cost": 38,
				"stats": {
					"hazardAvoid": 0.8
				},
				"desc": "Cameras pick a safe spot during descent, like Perseverance."
			}
		]
	},
	{
		"id": "mobility",
		"name": "Mobility",
		"surfaceOnly": true,
		"options": [
			{
				"id": "none",
				"name": "Stationary lander",
				"mass": 0,
				"cost": 0,
				"stats": {
					"rover": false
				},
				"desc": "No drive objectives possible."
			},
			{
				"id": "rover",
				"name": "Rover, standard wheels",
				"mass": 180,
				"cost": 40,
				"stats": {
					"rover": true,
					"wheelTol": 0.35
				},
				"desc": "Thin aluminium wheels."
			},
			{
				"id": "roverPlus",
				"name": "Rover, reinforced wheels",
				"mass": 210,
				"cost": 52,
				"stats": {
					"rover": true,
					"wheelTol": 0.75
				},
				"desc": "Thicker treads, lessons from Curiosity."
			},
			{
				"id": "roverPro",
				"name": "All-terrain rover, flexible mesh wheels",
				"mass": 225,
				"cost": 62,
				"stats": {
					"rover": true,
					"wheelTol": 0.9
				},
				"desc": "Reward equipment. Spring-mesh wheels that bend over sharp rocks instead of tearing.",
				"unlock": 2
			},
			{
				"id": "rotor",
				"name": "Rotorcraft (dense atmosphere only)",
				"mass": 200,
				"cost": 60,
				"stats": {
					"rover": true,
					"wheelTol": 0.95,
					"rotor": true
				},
				"desc": "Flies between sites, like Dragonfly on Titan.",
				"needs": "allowsRotor"
			}
		]
	},
	{
		"id": "probe",
		"name": "Atmospheric probe",
		"probeOnly": true,
		"options": [
			{
				"id": "std",
				"name": "Standard probe (rated 25 bar)",
				"mass": 340,
				"cost": 40,
				"stats": {
					"probeBar": 25,
					"probeHeat": 160
				},
				"desc": "Similar to the Galileo probe."
			},
			{
				"id": "deep",
				"name": "Deep probe (rated 60 bar)",
				"mass": 480,
				"cost": 70,
				"stats": {
					"probeBar": 60,
					"probeHeat": 330
				},
				"desc": "Thicker shell and insulation for deeper descent."
			}
		]
	},
	{
		"id": "spares",
		"name": "Maintenance resources",
		"options": [
			{
				"id": "s0",
				"name": "No spares",
				"mass": 0,
				"cost": 0,
				"stats": {
					"spares": 0
				},
				"desc": ""
			},
			{
				"id": "s2",
				"name": "2 repair kits",
				"mass": 30,
				"cost": 8,
				"stats": {
					"spares": 2
				},
				"desc": ""
			},
			{
				"id": "s4",
				"name": "4 repair kits",
				"mass": 60,
				"cost": 16,
				"stats": {
					"spares": 4
				},
				"desc": ""
			}
		]
	},
	{
		"id": "backup",
		"name": "Backup systems",
		"multi": true,
		"options": [
			{
				"id": "lga",
				"name": "Backup low-gain antenna",
				"mass": 10,
				"cost": 6,
				"stats": {
					"backupComms": true
				},
				"desc": "Slow but survives a main antenna failure."
			},
			{
				"id": "redund",
				"name": "Redundant instrument electronics",
				"mass": 25,
				"cost": 14,
				"stats": {
					"backupInst": true
				},
				"desc": "Swap in when instruments fail."
			},
			{
				"id": "nav2",
				"name": "Second star tracker",
				"mass": 8,
				"cost": 5,
				"stats": {
					"backupNav": true
				},
				"desc": "Restores navigation after a fault."
			}
		]
	}
]

const INSTRUMENTS := [
	{
		"id": "camera",
		"name": "Imaging camera",
		"tag": "imaging",
		"mass": 15,
		"cost": 8,
		"power": 2
	},
	{
		"id": "spectro",
		"name": "Spectrometer",
		"tag": "composition",
		"mass": 20,
		"cost": 12,
		"power": 3
	},
	{
		"id": "drill",
		"name": "Sample drill + analyser",
		"tag": "sample",
		"mass": 35,
		"cost": 20,
		"power": 5,
		"surfaceOnly": true
	},
	{
		"id": "weather",
		"name": "Weather / atmosphere station",
		"tag": "atmosphere",
		"mass": 8,
		"cost": 5,
		"power": 1
	},
	{
		"id": "thermal",
		"name": "Thermal mapper",
		"tag": "thermal",
		"mass": 12,
		"cost": 8,
		"power": 2
	},
	{
		"id": "magneto",
		"name": "Magnetometer",
		"tag": "fields",
		"mass": 8,
		"cost": 6,
		"power": 1
	},
	{
		"id": "radar",
		"name": "Ice-penetrating radar",
		"tag": "subsurface",
		"mass": 30,
		"cost": 18,
		"power": 5
	},
	{
		"id": "massspec",
		"name": "Mass spectrometer",
		"tag": "plume",
		"mass": 25,
		"cost": 16,
		"power": 4
	},
	{
		"id": "radmon",
		"name": "Radiation monitor",
		"tag": "radiation",
		"mass": 5,
		"cost": 3,
		"power": 1
	},
	{
		"id": "camCompact",
		"name": "Compact imaging camera (reward)",
		"tag": "imaging",
		"mass": 7,
		"cost": 6,
		"power": 1,
		"unlock": 1
	},
	{
		"id": "radarLow",
		"name": "Low-power ice radar (reward)",
		"tag": "subsurface",
		"mass": 18,
		"cost": 14,
		"power": 3,
		"unlock": 3
	},
	{
		"id": "massMini",
		"name": "Miniature mass spectrometer (reward)",
		"tag": "plume",
		"mass": 12,
		"cost": 12,
		"power": 2,
		"unlock": 4
	}
]

const LAUNCHERS := [
	{
		"id": "light",
		"name": "Light launcher",
		"cap": 1600,
		"cost": 60,
		"desc": "Small, cheap."
	},
	{
		"id": "medium",
		"name": "Medium launcher",
		"cap": 4200,
		"cost": 100,
		"desc": "The workhorse."
	},
	{
		"id": "heavy",
		"name": "Heavy launcher",
		"cap": 8500,
		"cost": 150,
		"desc": "For heavy, distant missions."
	}
]

const TRAJECTORIES := [
	{
		"id": "direct",
		"name": "Direct transfer",
		"massMul": 1,
		"fuel": 14,
		"cruiseMul": 1,
		"desc": "Shortest flight, needs a lot of launch energy."
	},
	{
		"id": "assist",
		"name": "Gravity assist route",
		"massMul": 1.8,
		"fuel": 8,
		"cruiseMul": 1.7,
		"desc": "Swings past planets to gain speed. Delivers more mass, takes longer (more cruise events)."
	}
]

const BUS := {
	"mass": 350,
	"cost": 40
}

const DIFFICULTY := {
	"beginner": {
		"id": "beginner",
		"name": "Beginner",
		"variability": 0.1,
		"eventChance": 0.28,
		"cycles": 3,
		"spares": 2,
		"budgetMul": 1.2,
		"guidance": true,
		"maxSimul": 1,
		"repairMul": 1.3,
		"desc": "Lower environmental variability, more time to recover, fewer complications, guidance hints."
	},
	"intermediate": {
		"id": "intermediate",
		"name": "Intermediate",
		"variability": 0.25,
		"eventChance": 0.42,
		"cycles": 0,
		"spares": 0,
		"budgetMul": 1,
		"guidance": false,
		"maxSimul": 2,
		"repairMul": 1,
		"desc": "Realistic conditions, several challenges at once, limited maintenance resources."
	},
	"advanced": {
		"id": "advanced",
		"name": "Advanced",
		"variability": 0.4,
		"eventChance": 0.55,
		"cycles": -2,
		"spares": -1,
		"budgetMul": 0.9,
		"guidance": false,
		"maxSimul": 3,
		"repairMul": 0.75,
		"desc": "Complex hazard combinations, limited recovery, demanding objectives. Equipment choices matter most."
	}
}

const MIX := {
	"1": {
		"env": 10,
		"universal": 20,
		"eng": 70
	},
	"2": {
		"env": 45,
		"universal": 35,
		"eng": 20
	},
	"3": {
		"env": 45,
		"universal": 35,
		"eng": 20
	},
	"4": {
		"env": 50,
		"universal": 30,
		"eng": 20
	},
	"5": {
		"env": 35,
		"universal": 35,
		"eng": 30
	}
}

const LEVELS := [
	{
		"n": 1,
		"name": "FIRST CONTACT",
		"difficulty": "Beginner",
		"theme": "Learning the Fundamentals",
		"intro": "Every great mission starts on the ground. Learn to budget, choose components, launch, reach orbit and make a first exploration, all close to home.",
		"completion": "Successfully design and operate a basic exploration mission.",
		"unlock": "Level 02: BEYOND EARTH"
	},
	{
		"n": 2,
		"name": "BEYOND EARTH",
		"difficulty": "Intermediate",
		"theme": "Interplanetary Exploration",
		"intro": "Leave Earth behind. Dust, furnace heat and crushing pressure will test whether your spacecraft was built for the world it visits.",
		"completion": "Complete an interplanetary exploration mission while managing planetary hazards and spacecraft condition.",
		"unlock": "Level 03: GIANTS OF THE SOLAR SYSTEM"
	},
	{
		"n": 3,
		"name": "GIANTS OF THE SOLAR SYSTEM",
		"difficulty": "Advanced",
		"theme": "Complex Planetary Exploration",
		"intro": "The giant planets have no ground to stand on. Orbit them, survive their radiation and rings, and send probes into their atmospheres.",
		"completion": "Successfully complete an advanced planetary exploration mission.",
		"unlock": "Level 04: UNKNOWN WORLDS"
	},
	{
		"n": 4,
		"name": "UNKNOWN WORLDS",
		"difficulty": "Expert",
		"theme": "Moons, Complex Environments and Scientific Discovery",
		"intro": "Some of the most exciting places in the Solar System are moons: ice shells over oceans, methane lakes, erupting volcanoes and water jets.",
		"completion": "Complete a specialised scientific exploration mission while responding to multiple environmental hazards.",
		"unlock": "Level 05: ODYSSEY"
	},
	{
		"n": 5,
		"name": "ODYSSEY",
		"difficulty": "Expert / Master",
		"theme": "Complete Mission Command",
		"intro": "Everything you have learned, all at once. Budgets shrink, systems fail, and the Solar System does not care about your plans.",
		"completion": "Successfully design, execute and evaluate a complete interplanetary exploration mission.",
		"unlock": "COSMOS MASTER MISSION STATUS"
	}
]

const STAGES := [
	{
		"n": 1,
		"level": 1,
		"name": "MISSION PREPARATION",
		"dest": "earth",
		"budget": 320,
		"phases": [
			"design",
			"plan"
		],
		"keepDesign": true,
		"types": [
			"Basic budget allocation",
			"Spacecraft component selection",
			"Scientific instrument selection",
			"Basic mission objective planning"
		],
		"brief": "Design an Earth-observation and test-landing spacecraft within budget. Your design is reused for the rest of Level 01.",
		"pass": "design"
	},
	{
		"n": 2,
		"level": 1,
		"name": "THE LAUNCH SEQUENCE",
		"dest": "earth",
		"budget": 320,
		"phases": [
			"launch"
		],
		"useDesign": true,
		"types": [
			"Launch preparation",
			"Payload weight restrictions",
			"Basic system diagnostics",
			"Launch schedule management"
		],
		"objectives": [
			{
				"id": "launch",
				"name": "Launch safely and reach space",
				"tag": "launch",
				"units": 1,
				"mode": "orbit",
				"primary": true
			}
		],
		"forced": {
			"launch": [
				"diagnostics",
				"launchWindow"
			]
		},
		"brief": "Prepare your spacecraft on the pad and get it safely into space.",
		"pass": "launch"
	},
	{
		"n": 3,
		"level": 1,
		"name": "INTO ORBIT",
		"dest": "earth",
		"budget": 320,
		"phases": [
			"launch",
			"arrive",
			"ops"
		],
		"useDesign": true,
		"quickLaunch": true,
		"crewed": true,
		"segments": [
			{
				"dest": "earth",
				"mode": "orbit",
				"cycles": 6
			}
		],
		"objectives": [
			{
				"id": "map",
				"name": "Map the landing test range",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "clouds",
				"name": "Track weather systems from orbit",
				"tag": "atmosphere",
				"units": 2,
				"mode": "orbit",
				"primary": false
			}
		],
		"types": [
			"Basic navigation",
			"Orbital positioning",
			"Power management",
			"Communication monitoring"
		],
		"forced": {
			"ops": [
				"orbitTrim",
				"powerCrisis"
			]
		},
		"brief": "A crewed orbital test flight. Reach a stable orbit, keep the power balanced, keep talking to the ground, and keep the crew safe.",
		"pass": "primary"
	},
	{
		"n": 4,
		"level": 1,
		"name": "FIRST EXPLORATION",
		"dest": "earth",
		"budget": 320,
		"phases": [
			"arrive",
			"ops"
		],
		"useDesign": true,
		"segments": [
			{
				"dest": "earth",
				"mode": "surface"
			}
		],
		"objectives": [
			{
				"id": "site",
				"name": "Image the landing site",
				"tag": "imaging",
				"units": 2,
				"mode": "surface",
				"primary": true
			},
			{
				"id": "weather",
				"name": "Record the weather",
				"tag": "atmosphere",
				"units": 2,
				"mode": "surface",
				"primary": false
			},
			{
				"id": "valley",
				"name": "Drive to the valley test site",
				"tag": "drive",
				"units": 2,
				"mode": "drive",
				"primary": false
			}
		],
		"types": [
			"Basic planetary observations",
			"Surface mapping",
			"Scientific data collection",
			"Simple equipment complications"
		],
		"forced": {
			"arrive": [
				"weatherHold"
			]
		},
		"brief": "A simulated landing on Earth's test range. Pick a landing region (not the ocean) and collect your first data.",
		"pass": "primary"
	},
	{
		"n": 5,
		"level": 2,
		"name": "THE RED PLANET",
		"dest": "mars",
		"budget": 440,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Martian dust accumulation",
			"Rocky terrain",
			"Rover mobility complications",
			"Temperature-related equipment stress",
			"Communication delays"
		],
		"brief": "Land on Mars, drive to an ancient river delta and drill a rock. Watch the dust on your panels.",
		"pass": "primary"
	},
	{
		"n": 6,
		"level": 2,
		"name": "THE EXTREME FRONTIER",
		"dest": "mercury",
		"budget": 440,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Extreme temperature variations",
			"Cratered terrain",
			"Thermal system management",
			"Solar exposure"
		],
		"brief": "Land on the world closest to the Sun. Sunlight is your power and your enemy.",
		"pass": "primary"
	},
	{
		"n": 7,
		"level": 2,
		"name": "THE CRUSHING WORLD",
		"dest": "venus",
		"budget": 390,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Extreme temperature",
			"Atmospheric pressure",
			"Equipment degradation",
			"Structural integrity management"
		],
		"brief": "No lander lasts long on Venus. Get the science before the heat gets inside.",
		"pass": "primary"
	},
	{
		"n": 8,
		"level": 2,
		"name": "MISSION INTERRUPTED",
		"dest": "mars",
		"budget": 320,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"segments": [
			{
				"dest": "mars",
				"mode": "orbit",
				"cycles": 8
			}
		],
		"objectives": [
			{
				"id": "map",
				"name": "Map landing sites for future missions",
				"tag": "imaging",
				"units": 3,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "air",
				"name": "Monitor dust in the atmosphere",
				"tag": "atmosphere",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "min",
				"name": "Map surface minerals",
				"tag": "composition",
				"units": 2,
				"mode": "orbit",
				"primary": false
			}
		],
		"types": [
			"Communication blackout",
			"Power fluctuations",
			"Navigation errors",
			"Instrument malfunctions"
		],
		"forced": {
			"cruise": [
				"navError"
			],
			"arrive": [
				"commsBlackout"
			],
			"ops": [
				"powerCrisis",
				"instrumentFailure"
			]
		},
		"brief": "A Mars orbiter mission where the spacecraft itself is the challenge. Expect failures and keep the mission alive.",
		"pass": "primary"
	},
	{
		"n": 9,
		"level": 3,
		"name": "THE JOVIAN FRONTIER",
		"dest": "jupiter",
		"budget": 420,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Radiation exposure",
			"Instrument interference",
			"Atmospheric probe operations",
			"Orbital observation challenges"
		],
		"brief": "Orbit Jupiter and drop a probe into its clouds. Your orbit decides your radiation dose.",
		"pass": "primary"
	},
	{
		"n": 10,
		"level": 3,
		"name": "BEYOND THE RINGS",
		"dest": "saturn",
		"budget": 420,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Ring particle hazards",
			"Orbital navigation",
			"Atmospheric probe operations",
			"Communication delays"
		],
		"brief": "Study Saturn's rings up close and send a probe into its atmosphere.",
		"pass": "primary"
	},
	{
		"n": 11,
		"level": 3,
		"name": "THE FROZEN FRONTIER",
		"dest": "uranus",
		"budget": 440,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Extreme cold",
			"Limited solar power",
			"Atmospheric probe operations",
			"Power management"
		],
		"brief": "Only one spacecraft has ever visited Uranus. Sunlight here is too weak for solar panels to matter much.",
		"pass": "primary"
	},
	{
		"n": 12,
		"level": 3,
		"name": "THE DISTANT FRONTIER",
		"dest": "neptune",
		"budget": 440,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Powerful atmospheric winds",
			"Limited solar energy",
			"Atmospheric probe operations",
			"Long-distance communication"
		],
		"brief": "Four hours of light-time from home. Your probe must survive the fastest winds in the Solar System.",
		"pass": "primary"
	},
	{
		"n": 13,
		"level": 4,
		"name": "EUROPA: BENEATH THE ICE",
		"dest": "europa",
		"budget": 520,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Icy surface fractures",
			"Radiation exposure",
			"Extreme cold",
			"Scientific instrument selection"
		],
		"brief": "Land on the ice above a hidden ocean, inside Jupiter's radiation belts.",
		"pass": "primary"
	},
	{
		"n": 14,
		"level": 4,
		"name": "TITAN: THE METHANE WORLD",
		"dest": "titan",
		"budget": 480,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Extremely low temperatures",
			"Hydrocarbon-rich environment",
			"Surface navigation",
			"Equipment compatibility"
		],
		"brief": "A world with rain, rivers and seas, but made of methane at −179 °C.",
		"pass": "primary"
	},
	{
		"n": 15,
		"level": 4,
		"name": "IO: THE VOLCANIC WORLD",
		"dest": "io",
		"budget": 460,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Volcanic activity",
			"Radiation exposure",
			"Changing geological conditions",
			"Surface equipment protection"
		],
		"brief": "Io's surface changes while you watch. Protect your lander from fallout and radiation.",
		"pass": "primary"
	},
	{
		"n": 16,
		"level": 4,
		"name": "ENCELADUS: THE HIDDEN OCEAN",
		"dest": "enceladus",
		"budget": 450,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Icy terrain",
			"Water-rich plumes",
			"Scientific sample collection",
			"Equipment contamination"
		],
		"brief": "Catch material from the jets that spray out of a buried ocean.",
		"pass": "primary"
	},
	{
		"n": 17,
		"level": 5,
		"name": "THE BUDGET TRAP",
		"dest": "titan",
		"budget": 480,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Sudden budget reduction",
			"Payload restrictions",
			"Instrument prioritisation",
			"Mission redesign"
		],
		"forced": {
			"design": [
				"budgetTrap"
			]
		},
		"brief": "Design a Titan mission. Then the funding changes.",
		"pass": "primary"
	},
	{
		"n": 18,
		"level": 5,
		"name": "LAST CHANCE",
		"dest": "jupiter",
		"budget": 420,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"types": [
			"Multiple spacecraft malfunctions",
			"Communication interruption",
			"Power shortage",
			"Emergency mission recovery"
		],
		"special": "lastChance",
		"brief": "Something is wrong on the way to Jupiter. Then something else. Keep the mission alive.",
		"pass": "primary"
	},
	{
		"n": 19,
		"level": 5,
		"name": "THE GAUNTLET",
		"dest": "mars",
		"budget": 450,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"segments": [
			{
				"dest": "venus",
				"mode": "flyby",
				"cycles": 2
			},
			{
				"dest": "mars",
				"mode": "surface"
			}
		],
		"extraObjectives": [
			{
				"id": "vflyby",
				"name": "Image Venus's clouds during the flyby",
				"tag": "imaging",
				"units": 1,
				"mode": "orbit",
				"primary": false,
				"seg": 0
			}
		],
		"types": [
			"Multiple planetary destinations",
			"Random mission events",
			"Resource limitations",
			"Environmental damage",
			"Changing mission objectives"
		],
		"special": "gauntlet",
		"brief": "A Venus flyby, then Mars. One challenge after another, with no time to rest.",
		"pass": "primary"
	},
	{
		"n": 20,
		"level": 5,
		"name": "THE FINAL ODYSSEY",
		"dest": "titan",
		"budget": 500,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"segments": [
			{
				"dest": "saturn",
				"mode": "orbit",
				"cycles": 4
			},
			{
				"dest": "titan",
				"mode": "surface"
			}
		],
		"extraObjectives": [
			{
				"id": "srings",
				"name": "Measure Saturn's rings from orbit",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true,
				"seg": 0
			}
		],
		"types": [
			"Complete spacecraft design",
			"Launch vehicle selection",
			"Mission trajectory planning",
			"Scientific instrument selection",
			"Multiple planetary environmental challenges",
			"Unexpected technical complications",
			"Final mission evaluation"
		],
		"brief": "A Cassini-Huygens style finale: orbit Saturn, then land on Titan. Everything you have learned, in one mission.",
		"pass": "primary"
	}
]

const SPECIALS := [
	{
		"id": "sm1",
		"name": "THE SILENT SYSTEM",
		"unlockLevel": 2,
		"dest": "mars",
		"budget": 300,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"segments": [
			{
				"dest": "mars",
				"mode": "orbit",
				"cycles": 7
			}
		],
		"objectives": [
			{
				"id": "map",
				"name": "Map the polar ice caps",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true
			},
			{
				"id": "air",
				"name": "Record atmospheric dust",
				"tag": "atmosphere",
				"units": 2,
				"mode": "orbit",
				"primary": false
			}
		],
		"forced": {
			"arrive": [
				"powerCrisis"
			],
			"ops": [
				"powerCrisis"
			]
		},
		"brief": "Recover from a spacecraft power emergency at Mars.",
		"types": [
			"Power emergency",
			"Power redistribution"
		]
	},
	{
		"id": "sm2",
		"name": "THE UNKNOWN",
		"unlockLevel": 2,
		"dest": "saturn",
		"budget": 420,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"forced": {
			"cruise": [
				"signal"
			],
			"ops": [
				"signal"
			]
		},
		"brief": "Investigate an unusual signal. Not every mystery is what it first seems.",
		"types": [
			"Unidentified signal",
			"Scientific investigation"
		]
	},
	{
		"id": "sm3",
		"name": "MISSION REBOOT",
		"unlockLevel": 3,
		"dest": "mars",
		"budget": 440,
		"phases": [
			"arrive",
			"ops"
		],
		"degraded": true,
		"special": "reboot",
		"brief": "A spacecraft reaches Mars with several systems below expected performance. Recover what you can.",
		"types": [
			"Inspect condition",
			"Prioritise repairs",
			"Reconsider objectives"
		]
	},
	{
		"id": "sm4",
		"name": "THE GAUNTLET",
		"unlockLevel": 4,
		"dest": "jupiter",
		"budget": 420,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"special": "gauntlet",
		"brief": "A sequence of unexpected events on the way to Jupiter.",
		"types": [
			"Budget restriction",
			"Payload limitation",
			"Navigation",
			"Communication",
			"Discovery"
		]
	},
	{
		"id": "sm5",
		"name": "BEYOND THE RINGS",
		"unlockLevel": 3,
		"dest": "saturn",
		"budget": 430,
		"phases": [
			"design",
			"launch",
			"cruise",
			"arrive",
			"ops"
		],
		"forceOrbit": "gap",
		"extraObjectives": [
			{
				"id": "gapsci",
				"name": "Sample particles inside the ring gap",
				"tag": "imaging",
				"units": 2,
				"mode": "orbit",
				"primary": true
			}
		],
		"brief": "An advanced Saturn scenario: Grand Finale dives between the rings and the planet.",
		"types": [
			"Ring gap dives",
			"Particle impacts"
		]
	}
]

const REWARDS := {
	"1": {
		"label": "Lightweight composite frame (−60 kg) · Compact imaging camera · Spacecraft model choice",
		"key": "lightFrame"
	},
	"2": {
		"label": "Advanced rover wheels (+0.1 wheel rating) · All-terrain rover · special mission THE SILENT SYSTEM",
		"key": "betterWheels"
	},
	"3": {
		"label": "Enhanced RTG (+2 power per cycle) · Low-power ice radar · Custom spacecraft builder · special missions THE UNKNOWN and MISSION REBOOT",
		"key": "eRTG"
	},
	"4": {
		"label": "Radiation-hardened avionics (+0.1 radiation rating) · Adaptive thermal system · Miniature mass spectrometer · special missions THE GAUNTLET and BEYOND THE RINGS",
		"key": "radHard"
	},
	"5": {
		"label": "COSMOS MASTER MISSION STATUS · Gold hull and accent colours",
		"key": "master"
	}
}

