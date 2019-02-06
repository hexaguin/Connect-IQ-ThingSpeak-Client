using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.Time;
using Toybox.Time.Gregorian;

class ThingSpeakClientView extends WatchUi.View {
	/*
██    ██  █████  ██████  ██  █████  ██████  ██      ███████ ███████
██    ██ ██   ██ ██   ██ ██ ██   ██ ██   ██ ██      ██      ██
██    ██ ███████ ██████  ██ ███████ ██████  ██      █████   ███████
 ██  ██  ██   ██ ██   ██ ██ ██   ██ ██   ██ ██      ██           ██
  ████   ██   ██ ██   ██ ██ ██   ██ ██████  ███████ ███████ ███████
*/


	var channelUrl = Application.getApp().getProperty("URL");
	hidden var mText = "Connecting to\nThingSpeak...";
	var tsDate;
	var fieldSuffixes = ["Pa", "C", "%"];
	var channelFields = [
		Application.getApp().getProperty("pressureField"),
		Application.getApp().getProperty("temperatureField"),
		Application.getApp().getProperty("humidityField"),
	];
	var fieldText = [];
	var fieldValues = [];
	var fieldColors = [ 
		[Graphics.COLOR_RED,    Graphics.COLOR_GREEN,    Graphics.COLOR_BLUE], //foreground
		[Graphics.COLOR_DK_RED, Graphics.COLOR_DK_GREEN, Graphics.COLOR_DK_BLUE] //accent
	];
	var edgeArcRanges = [ // Ranges that the edge arcs will represent
		[Application.getApp().getProperty("pressureMin"), Application.getApp().getProperty("pressureMax")],
		[Application.getApp().getProperty("temperatureMin"), Application.getApp().getProperty("temperatureMax")],
		[Application.getApp().getProperty("humidityMin"), Application.getApp().getProperty("humidityMax")]
	];
	var edgeArcCentered = [false, Application.getApp().getProperty("temperatureCentered"), false];
	
	function computeSeaLevel() {
		return fieldValues[0] * Math.pow(( 1.0 - (7.254 / (fieldValues[1] + 280.404))),-5.257);
	}
	
	
	/*
███████ ██    ██ ███    ██  ██████ ████████ ██  ██████  ███    ██ ███████
██      ██    ██ ████   ██ ██         ██    ██ ██    ██ ████   ██ ██
█████   ██    ██ ██ ██  ██ ██         ██    ██ ██    ██ ██ ██  ██ ███████
██      ██    ██ ██  ██ ██ ██         ██    ██ ██    ██ ██  ██ ██      ██
██       ██████  ██   ████  ██████    ██    ██  ██████  ██   ████ ███████
*/
	
	function parseISODate(date) {
		date = date.toString();
		System.println("ISODATE:");
		System.println(date);
		if (date.length() < 20) {
			return null;
		}
		var moment = Gregorian.moment({
			:year   => date.substring( 0,  4).toNumber(),
			:month  => date.substring( 5,  7).toNumber(),
			:day    => date.substring( 8, 10).toNumber(),
			:hour   => date.substring(11, 13).toNumber(),
			:minute => date.substring(14, 16).toNumber(),
			:second => date.substring(17, 19).toNumber()
		});
		var suffix = date.substring(19, date.length());

		// skip over to time zone
		var tz = 0;
		if (suffix.substring(tz, tz + 1).equals(".")) {
			while (tz < suffix.length()) {
				var first = suffix.substring(tz, tz + 1);
				if ("-+Z".find(first) != null) {
					break;
				}
				tz++;
			}
		}

		if (tz >= suffix.length()) {
			// no timezone given
			return null;
		}
		var tzOffset = 0;
		if (!suffix.substring(tz, tz + 1).equals("Z")) {
			// +HH:MM
			if (suffix.length() - tz < 6) {
				return null;
			}
			tzOffset  = suffix.substring(tz + 1, tz + 3).toNumber() * Gregorian.SECONDS_PER_HOUR;
			tzOffset += suffix.substring(tz + 4, tz + 6).toNumber() * Gregorian.SECONDS_PER_MINUTE;

			var sign = suffix.substring(tz, tz + 1);
			if (sign.equals("+")) {
				tzOffset = -tzOffset;
			} else if (sign.equals("-") && tzOffset == 0) {
				// -00:00 denotes unknown timezone
				return null;
			}
		}
		return moment.add(new Time.Duration(tzOffset));
}

	function stringToArray(inputString) {
		var outputArray = [];
		while(inputString.find(",")) {
			var commaIndex = inputString.find(",");
			outputArray.add(inputString.substring(0, commaIndex)); // Append everything before the first comma to the list
			inputString = inputString.substring(commaIndex, inputString.length()); // Drop the newly copied substring from the input string
		}
		return outputArray;
	}

	function makeRequest() {
		Communications.makeWebRequest(
			channelUrl,
			{},
			{"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			method(:onReceive)
		);
		System.println("Request Done");
	}
	
	function onReceive(responseCode, data) {
		System.println("Begin Receive");
		if (data instanceof Lang.String) {
			mText = data;
		}
		else if (data instanceof Dictionary) {
			var keys = data.keys();
			mText = "";
			System.println("ISODATE from JSON:");
			System.println(data["created_at"]);
			tsDate = parseISODate(data["created_at"]);
			
			for (var i = 0; i < channelFields.size(); i++ ) {
				fieldValues.add(data[keys[channelFields[i]]].toFloat());
			}
			
			if (Application.getApp().getProperty("useSeaLevel")) { //Convert to sea level pressure
				fieldValues[0] = computeSeaLevel();
			}
			
			for (var i = 0; i < fieldValues.size(); i++) {
				fieldText.add(Lang.format("$1$$2$", [fieldValues[i].toNumber(), fieldSuffixes[i] ]));
			}
		}
		WatchUi.requestUpdate();
		WatchUi.requestUpdate();
	  	System.println("End Receive");
	}
	
	function thickEdgeArc(dc, startAngle, endAngle, thickness){
		if (endAngle == startAngle) {
			return;
		}
		if(endAngle < startAngle){
			var s = startAngle;
			startAngle = endAngle;
			endAngle = s;
		}
		for(var i = 0; i <= thickness; i++){
			dc.drawArc(dc.getWidth()/2, dc.getHeight()/2, (dc.getWidth()/2)-i, Graphics.ARC_COUNTER_CLOCKWISE, startAngle, endAngle);
		}
	}
	
	function fractionOfRange(x, min, max){
		var f = (x - min) / (max - min);
		f = (f < 0.0) ? 0.0 : f;
		f = (f > 1.0) ? 1.0 : f;
		return f;
	}
	
	/*
███████ ████████  █████  ███    ██ ██████   █████  ██████  ██████       ██████  █████  ██      ██      ███████
██         ██    ██   ██ ████   ██ ██   ██ ██   ██ ██   ██ ██   ██     ██      ██   ██ ██      ██      ██
███████    ██    ███████ ██ ██  ██ ██   ██ ███████ ██████  ██   ██     ██      ███████ ██      ██      ███████
     ██    ██    ██   ██ ██  ██ ██ ██   ██ ██   ██ ██   ██ ██   ██     ██      ██   ██ ██      ██           ██
███████    ██    ██   ██ ██   ████ ██████  ██   ██ ██   ██ ██████       ██████ ██   ██ ███████ ███████ ███████
*/



	function initialize() {
		View.initialize();
	}

	// Load your resources here
	function onLayout(dc) {
		setLayout(Rez.Layouts.MainLayout(dc));
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() {
		makeRequest();
		System.println("onShow done");
	}

	// Update the view
	function onUpdate(dc) {
		// Call the parent onUpdate function to redraw the layout
		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
		dc.clear();
		if(	fieldText.size() == 0){
			dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_LARGE, mText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		} else {
			var entryAge = Time.now().subtract(tsDate).value()/60;
			dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK); 
			dc.drawText(dc.getWidth()/2, (dc.getHeight()/2) + 64, Graphics.FONT_XTINY, entryAge + "m Ago", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			
			for(var i = 0; i < 	fieldText.size(); i++){ // Text
				dc.setColor(fieldColors[0][i], Graphics.COLOR_BLACK); 
				dc.drawText(dc.getWidth()/2, (dc.getHeight()/2) + (i*32)-32, Graphics.FONT_LARGE, 	fieldText[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			}
			
			var arcLength = 360/fieldValues.size();
			for(var i = 0; i < fieldValues.size(); i++){ //Arcs
				var startAngle = arcLength*i;
				var filledLength = fractionOfRange(fieldValues[i], edgeArcRanges[i][0], edgeArcRanges[i][1]) * arcLength;
				
				dc.setColor(fieldColors[1][i], Graphics.COLOR_BLACK);
				thickEdgeArc(dc, startAngle, startAngle+arcLength, 10);
				dc.setColor(fieldColors[0][i], Graphics.COLOR_BLACK);
				
				if (edgeArcCentered[i]) {// Centered arc, eg temperature
					thickEdgeArc(dc, startAngle + (arcLength-filledLength), startAngle+(arcLength/2), 15);
				} else { //Normal Arc
					thickEdgeArc(dc, startAngle + (arcLength-filledLength), startAngle+arcLength, 15);
				}
			}
		}
		
		System.println("Update Done");
	}

	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory.
	function onHide() {
	}

}
