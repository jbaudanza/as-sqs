package com.beatlab.util {
	public class Logger {
    public static function info(string:String):void {
      log(string);
    }
    
    public static function error(string:String):void {
      log(string);
    }

    public static function debug(string:String):void {
//      log(string);
    }
    
    private static function log(string:String):void {
      var now:Date = new Date();
      trace( "[" + now.toString() + "] " + string);
    }
  }
}