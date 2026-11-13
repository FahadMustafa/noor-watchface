import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class NoorApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new NoorView()];
    }
}
