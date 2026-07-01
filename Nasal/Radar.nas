# ===============================================================
#                   Air and Terrain Mode Radar
#                    for Boeing P-8 Poseidon
#                     AMOROSO Paolo 06/2026
# ===============================================================
MPjoin = func(n) {
  var base = n.getValue();
  setprop("instrumentation/radar/" ~ base ~ "/radar/y-shift", 0);
  setprop("instrumentation/radar/" ~ base ~ "/radar/x-shift", 0);
  setprop("instrumentation/radar/" ~ base ~ "/radar/rotation", 0);
  setprop("instrumentation/radar/" ~ base ~ "/radar/in-range", 0);
  setprop("instrumentation/radar/" ~ base ~ "/radar/h-offset", 180);
  setprop("instrumentation/radar/" ~ base ~ "/joined", 1);
}

MPleave = func(n) {
  var base = n.getValue();
  setprop("instrumentation/radar/" ~ base ~ "/radar/in-range", 0);
  setprop("instrumentation/radar/" ~ base ~ "/joined", 0);
}

MPradarProperties = func {
  var targetList = props.globals.getNode("ai/models/").getChildren("multiplayer");
  foreach (d; props.globals.getNode("ai/models/").getChildren("aircraft")) {
    append(targetList, d);
  }

  foreach (m; targetList) {
    var name = m.getName();
    var index = m.getIndex();
    var path = "instrumentation/radar/ai/models/" ~ name ~ "[" ~ index ~ "]/";
    var sourcePath = "ai/models/" ~ name ~ "[" ~ index ~ "]/";

    if (getprop(path ~ "joined") == 1 or name == "aircraft") {
      var factor = getprop("instrumentation/radar/range-factor");
      if (factor == nil) factor = 1.0;

      var yNode = m.getNode("radar/y-shift", 0);
      var xNode = m.getNode("radar/x-shift", 0);
      var rotNode = m.getNode("radar/rotation", 0);
      var hOffNode = m.getNode("radar/h-offset", 0);
      var inRangeNode = m.getNode("radar/in-range", 0);

      var yVal = yNode != nil and yNode.getValue() != nil ? yNode.getValue() : 0;
      var xVal = xNode != nil and xNode.getValue() != nil ? xNode.getValue() : 0;
      var rotVal = rotNode != nil and rotNode.getValue() != nil ? rotNode.getValue() : 0;
      var hOffVal = hOffNode != nil and hOffNode.getValue() != nil ? hOffNode.getValue() : 0;
      var inRangeVal = inRangeNode != nil and inRangeNode.getValue() != nil ? inRangeNode.getValue() : 0;

      setprop(path ~ "radar/y-shift", yVal * factor);
      setprop(path ~ "radar/x-shift", xVal * factor);
      setprop(path ~ "radar/rotation", rotVal);
      setprop(path ~ "radar/h-offset", hOffVal);

      if (getprop("instrumentation/radar/selected") == 2) {
        var xShift = getprop(path ~ "radar/x-shift");
        if (xShift < -0.04 or xShift > 0.04) {
          setprop(path ~ "radar/in-range", 0);
        } else {
          setprop(path ~ "radar/in-range", inRangeVal);
        }
      } else {
        setprop(path ~ "radar/in-range", inRangeVal);
      }
    }
  }

  var selected = getprop("instrumentation/radar/selected");
  var range = getprop("instrumentation/radar/range");

  # Range Scaling Factor
  if (selected == 2) {
    if (range == 10) {
      setprop("instrumentation/radar/range", 20);
      setprop("instrumentation/radar/range-factor", 0.002);
    } elsif (range == 20) {
      setprop("instrumentation/radar/range-factor", 0.003246);
    } else {
      setprop("instrumentation/radar/range-factor", 0.001623);
    }
  } elsif (selected == 3 or selected == 4) {
    if (range == 40) {
      setprop("instrumentation/radar/range", 20);
      setprop("instrumentation/radar/range-factor", 0.001888);
    } elsif (range == 20) {
      setprop("instrumentation/radar/range-factor", 0.001888);
    } else {
      setprop("instrumentation/radar/range-factor", 0.003776);
    }
  }
  settimer(MPradarProperties, 0.05);
}

# =====================
#  Boresight Detecting
# =====================
locking=0;
found=-1;

boreSightLock = func {
  if (getprop("instrumentation/radar/selected") == 1) {
    targetList= props.globals.getNode("ai/models/").getChildren("multiplayer");

    foreach (d; props.globals.getNode("ai/models/").getChildren("aircraft")) {
      append(targetList,d);
    }

    foreach (m; targetList) {
      var string = "instrumentation/radar/ai/models/"~m.getName()~"["~m.getIndex()~"]";
      var string1 = "ai/models/"~m.getName()~"["~m.getIndex()~"]";
      if (getprop(string1~"radar/in-range")) {

        hOffset = getprop(string1~"radar/h-offset");
        vOffset = getprop(string1~"radar/v-offset");

        #really should be a cone, but is a square pyramid to avoid trigonemetry
        if(hOffset < 3 and hOffset > -3 and vOffset < 3 and vOffset > -3) {
          if (locking == 11) {
            setprop(string~"radar/boreLock",2);
            setprop("instrumentation/radar/lock",2);
            setprop("sim[0]/hud/current-color",1);
            locking -= 1;
          } elsif (locking ==1 or locking ==3 or locking ==5 or locking ==7 or locking ==9 ) {
            setprop("instrumentation/radar/lock",1);
            setprop(string1~"radar/boreLock",1);
          } else {
            setprop("instrumentation/radar/lock",0);
            setprop(string~"radar/boreLock",1);
          }

          if (found != m.getIndex()) {
            found=m.getIndex();
            locking=0;
          } else {
            locking += 1;
          }
          settimer(boreSightLock, 0.2);
          return;
        }
      }
    }
    setprop(string~"radar/boreLock",0);
    locking=0;
    setprop("sim[0]/hud/current-color",0);
  }

  locking=0;
  setprop("sim[0]/hud/current-color",0);
  found =-1;
  setprop("instrumentation/radar/lock",0);

  settimer(boreSightLock, 0.2);
}

setlistener("ai/models/model-added", MPjoin);
setlistener("ai/models/model-removed", MPleave);
settimer(MPradarProperties,1.0);
settimer(boreSightLock, 1.0);

#================================================================
#                      Terrain Radar Mode
#================================================================
print("*** LOADING TERRAIN-MAP ***");

var row          = 0;
var RAD2DEG      = 57.2957795;
var DEG2RAD      = 0.016774532925;
var TM_Path      = "/instrumentation/terrain-map/pixels/";

# Function to get Elevation at latitude and longitude
var TM_get_elevation = func (lat, lon) {
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

      var elevation = TM_get_elevation(pointlat, pointlon);

      setprop(TM_Path ~ "row[" ~ row ~ "]/col[" ~ col ~ "]/elevation-ft", elevation);
    }

    # Interpolate the rest of the points in each column

    for (var col = 1; col <= 29; col += 2) {
      var elevprev = getprop(TM_Path ~ "row[" ~ row ~ "]/col[" ~ (col - 1) ~ "]/elevation-ft");
      var elevnext = getprop(TM_Path ~ "row[" ~ row ~ "]/col[" ~ (col + 1) ~ "]/elevation-ft");
      var elevation = (elevprev + elevnext) / 2;

      setprop(TM_Path ~ "row[" ~ row ~ "]/col[" ~ col ~ "]/elevation-ft", elevation);
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
  print("Terrain Map READY");
});