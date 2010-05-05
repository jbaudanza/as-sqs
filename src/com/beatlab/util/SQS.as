package com.beatlab.util {
  
  import com.hurlant.crypto.hash.HMAC;
  import com.hurlant.util.Base64;
  import com.hurlant.crypto.Crypto;
  import com.hurlant.crypto.hash.IHash;
  
  import flash.utils.ByteArray;
  import flash.net.*;
  import flash.events.*;
  
  public class SQS {
    
    public function SQS(awsId:String, secret:String) {
      _awsId = awsId;
      
      _secret = new ByteArray();
      _secret.writeUTFBytes(secret);
    }
    
    private var _awsId:String;
    private var _secret:ByteArray;
    
    public function deleteMessage(uri:String, receiptHandle:String):void {
      var queryVars:URLVariables = createQueryVars('DeleteMessage');
      queryVars.ReceiptHandle = receiptHandle;
      makeRequest(uri, queryVars);
    }
    
    public function receiveMessage(uri:String, callback:Function, onEmpty:Function=null):void {
      var queryVars:URLVariables = createQueryVars('ReceiveMessage');
      
      var sqsNS:Namespace = new Namespace("http://queue.amazonaws.com/doc/2009-02-01/");
      
      makeRequest(uri, queryVars, function(xml:XML):void {
        var messagesReceived:Boolean = false;
        
        for each( var message:XML in xml.sqsNS::ReceiveMessageResult.sqsNS::Message ) {
          callback(message.sqsNS::Body, message.sqsNS::ReceiptHandle, message.sqsNS::MessageId);
          messagesReceived = true;
        }
        
        if(!messagesReceived && onEmpty != null) {
          onEmpty();
        }
      });
    }
    
    public function popMessage(uri:String, callback:Function):void {
      receiveMessage(uri, function(body:String, receiptHandle:String):void {
        callback(body);
        deleteMessage(uri, receiptHandle);
      });
    }
    
    public function sendMessage(uri:String, message:String):void {      
      var queryVars:URLVariables = createQueryVars('SendMessage');
      queryVars.MessageBody = message;
      makeRequest(uri, queryVars);
    }
        
    private function makeRequest(uri:String, queryVars:URLVariables, onComplete:Function = null):void {
      var plaintext:ByteArray = new ByteArray();
      queryVars.Timestamp = iso8601(new Date());
      queryVars.SignatureVersion = 2;
      queryVars.Version = '2009-02-01';
      queryVars.SignatureMethod = 'HmacSHA256';
      
      plaintext.writeUTFBytes(signatureString('GET', uri, queryVars));

      var hmac:HMAC = Crypto.getHMAC('sha256');
      var signature:ByteArray = hmac.compute(_secret, plaintext);

      queryVars.Signature = Base64.encodeByteArray(signature);

      var request:URLRequest = new URLRequest();
      request.method = URLRequestMethod.GET;
      request.data = queryVars;
      request.url = "http://queue.amazonaws.com" + uri;
      var loader:URLLoader = new URLLoader();
      
      if(onComplete != null) {
        loader.addEventListener(Event.COMPLETE, function(event:Event):void {
          try {
            var xml:XML = new XML(loader.data);
            onComplete(xml);
          } catch (e:TypeError) {
            Logger.error("Could not parse the XML file.");
          }
        });
      }
      
      loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, function(event:HTTPStatusEvent):void {
        if( event.status != 200 ) {
  		    Logger.error("HTTP Status code " + event.status + " from SQS");
	      }
			});
			
      loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOErrorEvent):void {
        trace("IO Error requesting: " + uri + " with query " + queryVars);
        trace("Retrying in 10 seconds");
        flash.utils.setTimeout(function():void{ 
          makeRequest(uri, queryVars, onComplete);
        }, 10000);
      });
      
      loader.load(request);
    }
    
    private function createQueryVars(action:String):URLVariables {
      var queryVars:URLVariables = new URLVariables();
      queryVars.AWSAccessKeyId = _awsId;
      queryVars.Action = action;
      return queryVars;
    }
    
    /* Converts a number to a string and adds leading zeros */
    private function padNumber(number:Number, padding:uint, radix:Number = 10):String {
      var str:String = number.toString(radix);
      
      if( str.length >= padding ) {
        return str;
      } else {
        var prefix:String = "";
        var length:uint = padding - str.length;
        for( var i:uint=0; i<length; i++ ) {
          prefix = prefix + "0";
        }
        return prefix + str;
      }
    }
    
    private function iso8601(date:Date):String {
      return padNumber(date.getUTCFullYear(), 4) + "-" +
        padNumber(date.getUTCMonth() + 1, 2) + "-" + 
        padNumber(date.getUTCDate(), 2) + "T" + 
        padNumber(date.getUTCHours(), 2) + ":" +
        padNumber(date.getUTCMinutes(), 2) + ":" +
        padNumber(date.getUTCSeconds(), 2) + "Z";
    }
    
    private function escapeForSignature(string:String):String {
      return string.replace(/[^a-zA-Z0-9\-\_\.\~]/g, function():String {
        return "%" + padNumber(arguments[0].charCodeAt(0), 2, 16).toLocaleUpperCase();
      });
    }
    
    private function signatureString(httpMethod:String, uri:String, queryVars:URLVariables):String {      
      // Create a sorted list of query variables
      var sortedVars:Array = new Array();
      for(var i:String in queryVars) {
        if(i != 'Signature') {
          sortedVars = sortedVars.concat(i).sort();
        }
      }
      
      var queryParts:Array = new Array();
      for(var j:uint; j<sortedVars.length; j++) {
        var key:String = sortedVars[j];
        queryParts = queryParts.concat(
          key + '=' + escapeForSignature(queryVars[key])
        )
      }
      
      var stringToSign:String = 
      [ httpMethod, 'queue.amazonaws.com', uri, queryParts.join('&') ].join("\n");
      
      return stringToSign;
    }    
  }
}