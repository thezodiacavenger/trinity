import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class TrinityApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        scheduleBridge();
        return [new TrinityView()];
    }

    //! Background service: polls the optional Trinity Bridge for calendar categories.
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new TrinityBridgeService()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        if (data instanceof Dictionary) {
            data.put("rx", Time.now().value());
            Application.Storage.setValue("bridge", data);
        }
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() as Void {
        scheduleBridge();
        WatchUi.requestUpdate();
    }

    //! Only wake the background process when a Bridge URL is configured. 15 min keeps battery cost low
    //! (Connect IQ's floor is 5 min).
    function scheduleBridge() as Void {
        var url = null;
        try { url = Application.Properties.getValue("BridgeUrl"); } catch (e) { url = null; }
        if (url instanceof String && url.length() > 0) {
            Background.registerForTemporalEvent(new Time.Duration(15 * 60));
        } else {
            Background.deleteTemporalEvent();
            Application.Storage.deleteValue("bridge");
        }
    }
}
