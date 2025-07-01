################################################
#                                              #
# Based on Boeing 787-8 Dreamliner Terrain Map #
#                                              #
# BARANGER Emmanuel aka Helijah  06/2022       #
################################################
print("*** LOADING TERRAIN-MAP.nas ... ***");

var row          = 0;
var RAD2DEG      = 57.2957795;
var DEG2RAD      = 0.016774532925;
var terrain      = "/instrumentation/terrain-map/pixels/";
var terrain_full = "/instrumentation/terrain-map[1]/pixels/";

# Function to get Elevation at latitude and longitude
var get_elevation = func (lat, lon) {
  var info = geodinfo(lat, lon);

  if (info == nil ) {
    var elevation = -1;                            # Unknown
  } elsif (info[1] == nil) {
    var elevation = info[0] * 3.2808399;           # Building
  } elsif (info[1].solid == 0) {
    var elevation = 0;                             # Water
  } else {
    var elevation = info[0] * 3.2808399;           # other
  }

  return elevation;
}

var terrain_map = {

  init : func {
    me.UPDATE_INTERVAL = 0.025;
    me.loopid = 0;
    me.reset();
  },

  update : func {

    var poslon      = getprop("/position/longitude-deg");
    var poslat      = getprop("/position/latitude-deg");
    var heading     = getprop("/orientation/heading-magnetic-deg");

    var range       = getprop("/instrumentation/radar/range");
    var displaymode = getprop("/instrumentation/radar/display-mode");

    #print("Display mode ......... ",displaymode);
    #print("Row          ......... ",row);

    # First get all the points (16x16)
    for (var col = 0; col <= 30; col += 2) {

      var projlon = poslon + ((-1 * (col-16) * (range/30) * math.sin(DEG2RAD * (heading - 90))) / 60);
      var projlat = poslat + ((-1 * (col-16) * (range/30) * math.cos(DEG2RAD * (heading - 90))) / 60);

      if (displaymode == 'ARC') {                                                             # just represent ahead
        var pointlon = projlon + ((row * (range/30) / 60) * math.sin(DEG2RAD * heading));
        var pointlat = projlat + ((row * (range/30) / 60) * math.cos(DEG2RAD * heading));
      } else {                                                                                 # Represent ahead and back
        var pointlon = projlon + (((row-16) * (range/30) / 60) * math.sin(DEG2RAD * heading));
        var pointlat = projlat + (((row-16) * (range/30) / 60) * math.cos(DEG2RAD * heading));
      }

      var elevation = get_elevation(pointlat, pointlon);

      setprop(terrain ~ "row[" ~ row ~ "]/col[" ~ col ~ "]/elevation-ft", elevation);
    }

    # Interpolate the rest of the points in each column

    for (var col = 1; col <= 29; col += 2) {
      var elevprev = getprop(terrain ~ "row[" ~ row ~ "]/col[" ~ (col - 1) ~ "]/elevation-ft");
      var elevnext = getprop(terrain ~ "row[" ~ row ~ "]/col[" ~ (col + 1) ~ "]/elevation-ft");
      var elevation = (elevprev + elevnext) / 2;

      setprop(terrain ~ "row[" ~ row ~ "]/col[" ~ col ~ "]/elevation-ft", elevation);
    }

    row += 1;

    if (row == 31) {
      row = 0;
    }
  },

  reset : func {
    me.loopid += 2;
    me._loop_(me.loopid);
  },
  _loop_ : func(id) {
    id == me.loopid or return;
    me.update();
    settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL);
  }
};

###  Main loop ###
setlistener("sim/signals/fdm-initialized", func {
  terrain_map.init();
  print("Terrain Map ......... Initialized");
});
