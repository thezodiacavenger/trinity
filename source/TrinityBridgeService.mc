import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

//! Fetches today's calendar *categories* (never titles) from the Trinity Bridge.
//! Expected JSON (flat, < 1 KB):
//!   { "v":1, "nIn":42, "nCat":"MTG", "meet":180, "pers":30, "read":0, "train":60, "focus":90 }
//!   nIn  = minutes until the next event starts (negative = in progress)
//!   nCat = MTG | LUNCH | PERS | READ | TRAIN | FOCUS | TRAVEL
//!   meet/pers/read/train/focus = minutes scheduled today in each category
(:background)
class TrinityBridgeService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var url = Application.Properties.getValue("BridgeUrl");
        var token = Application.Properties.getValue("BridgeToken");
        if (!(url instanceof String) || url.length() == 0) {
            Background.exit(null);
            return;
        }
        var params = {};
        if (token instanceof String && token.length() > 0) { params.put("token", token); }
        Communications.makeWebRequest(url, params, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Dictionary && data.get("error") == null) {
            Background.exit(data);
        } else {
            Background.exit(null);
        }
    }
}
