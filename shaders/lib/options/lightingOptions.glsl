#define sun_illuminance 100000.0
#define moon_illuminance 0.32

#define sunColorBase (blackbody(5778.0) * sun_illuminance)
#define moonColorBase (blackbody(4000.0) * moon_illuminance)