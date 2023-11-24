/* ----------------------------------------------------------------------------
FILE: fnc_handleMarkersSWT.sqf

FUNCTION: OCAP_recorder_fnc_handleMarkersSWT

Description:
  Used for tracking all markers in the Sweet Markers system.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(handleMarkersSWT);

Public:
  No

Author:
  IndigoFox, ilbinek
---------------------------------------------------------------------------- */
#include "script_component.hpp"

// VARIABLE: OCAP_recorder_trackedMarkers
// Persistent global variable on server that defines unique marker names currently being tracked.
// Entries are added at marker create events and removed at marker delete events to avoid duplicate processing.
GVAR(trackedMarkers) = []; // Markers which we save into replay
GVAR(trackedMarkersSWT) = [] call CBA_fnc_hashCreate; // Markers which we save into replay - But keep the data in the array for SWT

// VARIABLE: OCAP_listener_markers
// Contains handle for <OCAP_handleMarker> CBA event handler.

// CBA Event: OCAP_handleMarkersSWT
// Handles marker creation, modification, and deletion events.
EGVAR(listener,markers) = [QGVARMAIN(handleMarkersSWT), {
  if (!SHOULDSAVEEVENTS) exitWith {};

  params["_eventType", "_mrk_name", "_mrk_owner", "_pos", "_type", "_shape", "_size", "_dir", "_brush", "_color", "_alpha", "_text", ["_forceGlobal", false], ["_creationTime", 0]];

  switch (_eventType) do {
    case "CREATED": {
      if (GVARMAIN(isDebug)) then {
        OCAPEXTLOG(ARR2("MARKER:CREATE: Processing marker data -- ", _mrk_name));
      };

      if (_mrk_name in GVAR(trackedMarkers)) exitWith {
        if (GVARMAIN(isDebug)) then {
          OCAPEXTLOG(ARR3("MARKER:CREATE: Marker", _mrk_name, "already tracked, exiting"));
        };
      };

      if (GVARMAIN(isDebug)) then {
        format["CREATE:MARKER: Valid CREATED process of %1, sending to extension", _mrk_name] SYSCHAT;
        OCAPEXTLOG(ARR3("CREATE:MARKER: Valid CREATED process of", _mrk_name, ", sending to extension"));
      };

      if (_type isEqualTo "") then {_type = "mil_dot"};
      GVAR(trackedMarkers) pushBackUnique _mrk_name;

      private _mrk_color = "";
      if (_color == "Default") then {
        _mrk_color = (configfile >> "CfgMarkers" >> _type >> "color") call BIS_fnc_colorConfigToRGBA call bis_fnc_colorRGBtoHTML;
      } else {
        _mrk_color = (configfile >> "CfgMarkerColors" >> _color >> "color") call BIS_fnc_colorConfigToRGBA call bis_fnc_colorRGBtoHTML;
      };

      private ["_sideOfMarker"];
      if (_mrk_owner isEqualTo objNull) then {
        _forceGlobal = true;
        _mrk_owner = -1;
        _sideOfMarker = -1;
      } else {
        _sideOfMarker = (side _mrk_owner) call BIS_fnc_sideID;
        _mrk_owner = _mrk_owner getVariable[QGVARMAIN(id), 0];
      };

      if (_sideOfMarker isEqualTo 4 ||
        (["Projectile#", _mrk_name] call BIS_fnc_inString) ||
        (["Detonation#", _mrk_name] call BIS_fnc_inString) ||
        (["Mine#", _mrk_name] call BIS_fnc_inString) ||
        (["ObjectMarker", _mrk_name] call BIS_fnc_inString) ||
        (["moduleCoverMap", _mrk_name] call BIS_fnc_inString) ||
        _forceGlobal) then {_sideOfMarker = -1};

      private ["_polylinePos"];
      if (count _pos > 3) then {
        _polylinePos = [];
        for [{_i = 0}, {_i < ((count _pos) - 1)}, {_i = _i + 1}] do {
          _polylinePos pushBack [_pos # (_i), _pos # (_i + 1)];
          _i = _i + 1;
        };
        _pos = _polylinePos;
      };

      if (isNil "_dir") then {
        _dir = 0;
      } else {if (_dir isEqualTo "") then {_dir = 0}};
    
      private _captureFrameNo = GVAR(captureFrameNo);
      if (_creationTime > 0) then {
        private _delta = time - _creationTime;
        private _lastFrameTime = (GVAR(captureFrameNo) * GVAR(frameCaptureDelay)) + GVAR(startTime);
        if (_delta > (time - _lastFrameTime)) then { // marker was initially created in some frame(s) before
          _captureFrameNo = ceil _lastFrameTime - (_delta / GVAR(frameCaptureDelay));
          private _logParams = (str [GVAR(captureFrameNo), time, _creationTime, _delta, _lastFrameTime, _captureFrameNo]);

          if (GVARMAIN(isDebug)) then {
            OCAPEXTLOG(ARR2("CREATE:MARKER: adjust frame ", _logParams));
          };
        };
      };

      private _logParams = (str [_mrk_name, _dir, _type, _text, _captureFrameNo, -1, _mrk_owner, _mrk_color, _size, _sideOfMarker, _pos, _shape, _alpha, _brush]);

      [":MARKER:CREATE:", [_mrk_name, _dir, _type, _text, _captureFrameNo, -1, _mrk_owner, _mrk_color, _size, _sideOfMarker, _pos, _shape, _alpha, _brush]] call EFUNC(extension,sendData);
    };

    case "UPDATED": {
      if (_mrk_name in GVAR(trackedMarkers)) then {
        if (isNil "_dir") then {_dir = 0};
        [":MARKER:MOVE:", [_mrk_name, GVAR(captureFrameNo), _pos, _dir, _alpha]] call EFUNC(extension,sendData);
      };
    };

    case "DELETED": {
      if (_mrk_name in GVAR(trackedMarkers)) then {

        if (GVARMAIN(isDebug)) then {
          format["MARKER:DELETE: Marker %1", _mrk_name] SYSCHAT;
          OCAPEXTLOG(ARR3("MARKER:DELETE: Marker", _mrk_name, "deleted"));
        };

        [":MARKER:DELETE:", [_mrk_name, GVAR(captureFrameNo)]] call EFUNC(extension,sendData);
        GVAR(trackedMarkers) = GVAR(trackedMarkers) - [_mrk_name];
      };
    };
  };
}] call CBA_fnc_addEventHandler;

// CBA Events called from SWT itself
["SWT_fnc_createMarker", {
  // TODO HANDLE ELLIPSES AND LINES
  params ["_player", "_marker"];
  // Marker - array - [marker name, channel, text, [position], type, color (number), direction, scale, owner name, time, "(literally just "")", owner side]
  // Explode the _marker into vars
  _marker params ["_name", "_channel", "_text", "_pos", "_type", "_color", "_dir", "_scale", "_ownerName", "_time", "_brush", "_side"];
  
  // Check if the marker is already tracked
  if (_name in GVAR(trackedMarkers)) exitWith {};

  // Track only Side and Global markers
  if (_channel != "S" && _channel != "GL") exitWith {};

  // If marker is supposed to be global, change _player to objNul
  if (_channel == "GL") then {_player = objNull};
  // Change the color to a text representation - swt_cfgmarkerColors_names is a global var with this representation
  _color = swt_cfgMarkerColors_names select _color;

  private _size = [1, 1];
  private _shape = "ICON";
  private _brush = "SOLID";
  // Change the type to a text representation - swt_cfgMarkers_names is a global var with this representation
  if (_type == -2) then {
    diag_log _scale;
    _type = "mil_dot";
    _shape = "RECTANGLE";
    _brush = "SolidBorder";
    _size = [_scale#0, _scale#1];
  } else {
    if (_type == -3) then {
      diag_log _scale;
      _type = "mil_dot";
      _shape = "ELLIPSE";
      _brush = "SolidBorder";
      _size = [_scale#0, _scale#1];
    } else {
      _type = swt_cfgMarkers_names select _type;
      _size = [ _scale, _scale];
    };
  };
  
  // Pos add elevation? Ask Indigo
  _pos set [2, 69420];

  // Create params to pass to the event handler
  private _params = ["CREATED", _name, _player, _pos, _type, _shape, _size, _dir, _brush, _color, 1, _text, false, _time];

  [GVAR(trackedMarkersSWT), _name, _params] call CBA_fnc_hashSet;

  [QGVARMAIN(handleMarkersSWT), _params] call CBA_fnc_localEvent;
}] call CBA_fnc_addEventHandler;

["SWT_fnc_dirMarker", {
  params ["_marker", "_dir", "_player"];

  private _m = [GVAR(trackedMarkersSWT), _marker] call CBA_fnc_hashGet;

  _m set [7, _dir];
  [GVAR(trackedMarkersSWT), _marker, _m] call CBA_fnc_hashSet;
  private _params = ["UPDATED", _marker, _m#2, _m#3, "", "", "", _dir, "", "", 1];

  [QGVARMAIN(handleMarkersSWT), _params] call CBA_fnc_localEvent;
}] call CBA_fnc_addEventHandler;

["SWT_fnc_removeMarker", {
  params ["_marker", "_player"];

  [GVAR(trackedMarkersSWT), _marker, []] call CBA_fnc_hashSet;

  [QGVARMAIN(handleMarkersSWT), ["DELETED", _marker, _player]] call CBA_fnc_localEvent;
}] call CBA_fnc_addEventHandler;

["SWT_fnc_moveMarker", {
  params ["_marker", "_pos", "_player"];

  private _m = [GVAR(trackedMarkersSWT), _marker] call CBA_fnc_hashGet;

  _m set [3, _pos];
  [GVAR(trackedMarkersSWT), _marker, _m] call CBA_fnc_hashSet;
  private _params = ["UPDATED", _marker, _m#2, _pos, "", "", "", _m7, "", "", 1];

  [QGVARMAIN(handleMarkersSWT), _params] call CBA_fnc_localEvent;
}] call CBA_fnc_addEventHandler;

// Collect all initial markers
[
  {getClientStateNumber > 8 && !isNil QGVAR(startTime)},
  {
    // Iterate through all the sides that have put markers down
    private _i = 1;
    while {true} do {
      if (_i >= count swt_markers_logicServer_s) then { 
        break; 
      };

      // Iterate through every marker
      {
        // Player is not set, so need to find it by name
        private _player = _x#8;
        {
          if (name _x == _player) exitWith {_player = _x};
        } foreach allPlayers;
        // Call create marker event on it
        ["SWT_fnc_createMarker", [_player, _x]] call CBA_fnc_localEvent;
      } foreach swt_markers_logicServer_s#_i;
      _i = _i + 2;
    };

    LOG("GETINITIALMARKERS: Successfully parsed markers created during briefing phase");
    if (GVARMAIN(isDebug)) then {
      "GETINITIALMARKERS: Successfully parsed markers created during briefing phase" SYSCHAT;
      OCAPEXTLOG(["GETINITIALMARKERS: Successfully parsed markers created during briefing phase"]);
    };
  }
] call CBA_fnc_waitUntilAndExecute;
