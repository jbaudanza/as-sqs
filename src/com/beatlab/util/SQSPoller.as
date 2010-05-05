package com.beatlab.util {
  import com.beatlab.util.SQS;
  import flash.utils.*;
  import com.beatlab.util.Logger;
  
  public class SQSPoller {
    
    public function SQSPoller(sqs:SQS, uri:String, callback:Function, interval:uint) {
      _uri = uri;
      _sqs = sqs;
      _interval = interval;
      _callback = callback;
    }
    
    public function start():void {
      setTimeout(function():void {
        Logger.debug("polling");
        _sqs.receiveMessage(_uri, _callback, function():void { start(); });
      }, _interval);
    }
    
    private var _callback:Function;
    private var _uri:String;
    private var _sqs:SQS;
    private var _interval:uint;
  }
}