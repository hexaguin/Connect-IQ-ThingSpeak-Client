using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.Time;
using Toybox.Time.Gregorian;

class ThingSpeakClientView extends WatchUi.View {
	hidden var mText = "Loading Data...";
	var tsDate;
	var fieldLabels = ["Humidity", "Pressure", "Temperature"];
	var fieldSuffixes = ["%", "Pa", "C"];
	var fieldText = [];
	var fieldValues = [];
	var fieldColors = [ 
		[Graphics.COLOR_BLUE,    Graphics.COLOR_GREEN,    Graphics.COLOR_RED], //foreground
		[Graphics.COLOR_DK_BLUE, Graphics.COLOR_DK_GREEN, Graphics.COLOR_DK_RED] //accent
	];
	var edgeArcRanges = [ // Ranges that the edge arcs will represent
		[0, 100],
		[75000, 105000],
		[-25, 25]
	];
	var edgeArcCentered = [false, false, true];
	
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

	function makeRequest() {
		Communications.makeWebRequest(
			"https://api.thingspeak.com/channels/579417/feeds/last.json",
			{
			},
			{
				"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
			},
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
			for( var i = 0; i < fieldLabels.size(); i++ ) { 
				fieldValues.add(data[keys[i+1]].toFloat());
				fieldText.add(Lang.format("$1$$2$", [Math.round(data[keys[i+1]].toFloat()).toNumber(), fieldSuffixes[i] ]));
			}
		}
		WatchUi.requestUpdate();
		WatchUi.requestUpdate();
	  	System.println("End Receive");
	}

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
	
	function thickEdgeArc(dc, startAngle, endAngle, thickness){
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
		var f = (x-min)/max;
		f = (f < 0.0) ? 0.0 : f;
		f = (f > 1.0) ? 1.0 : f;
		return f;
	}

	// Update the view
	function onUpdate(dc) {
		// Call the parent onUpdate function to redraw the layout
		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_BLACK);
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
