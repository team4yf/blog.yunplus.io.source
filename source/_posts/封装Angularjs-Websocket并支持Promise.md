title: 封装Angularjs Websocket并支持Promise
author: Wangfan
tags:
  - angularjs
  - ng
  - websocket
  - promise
categories:
  - code
date: 2017-02-17 15:15:00
---
最近完成了一个ionic项目，服务端是用的websocket，之前还没应用过ws来做前后端的交互；经过这个项目的实践，将这段代码进行封装，并做简要的说明。

### 1.添加依赖[$websocket]

 这个不多说，这个模块是ng1中使用websocket的不二之选，官方文档也很详细：[传送门](https://github.com/gdi2290/angular-websocket)。
 
 官方实例是这么写的：
 
 ```JAVASCRIPT
    angular.module('YOUR_APP', [
      'ngWebSocket' // you may also use 'angular-websocket' if you prefer
    ])
    //                          WebSocket works as well
    .factory('MyData', function($websocket) {
      // Open a WebSocket connection
      var dataStream = $websocket('ws://website.com/data');

      var collection = [];

      dataStream.onMessage(function(message) {
        collection.push(JSON.parse(message.data));
      });

      var methods = {
        collection: collection,
        get: function() {
          dataStream.send(JSON.stringify({ action: 'get' }));
        }
      };

      return methods;
    })
    .controller('SomeController', function ($scope, MyData) {
      $scope.MyData = MyData;
    });

 ```
   如果你的项目中没有复杂的交互，仅仅是在一个页面中存取数据，这样已经足够了。
 
   但往往项目稍微复杂的应用都无法通过这个来满足。
 
   以下是我个人的简单实现；也仅仅是一种思路的实现，仅供参考 :D
<!-- more -->
### 2.将callback转换成promise的实现
 
  思路核心：
  
>  1. push callback to an array => 
   将callback添加到一个数组中得到一个id    
>  2. defer with $q.promise => 
   通过$q来挂起callback    
>  3. send request with a callbackid => 
   在发送请求的时候带着这个id   
>  4. resolve the promise after websocket.onMessage => 
   websocket响应之后通知promise    
>  5. get the callback from the array with the callbackid => 
   通过返回的callbackid 从数组中取到这个callback    
>  6. do the callback code things. 
   执行想要的代码
    

- 下面是完整代码

```JAVASCRIPT
"use strict";

(function() {

   angular.module('io.y+.ws', ['ngWebSocket'])
    .factory('yws', ['$websocket', '$q', function ($websocket, $q) {
      //---- options of the lib
      var _options = {
        endpoint: 'ws://localhost:8089',
        channels: []
      };

      //---- websocket instance
      var _dataStream;

      //---- callback arrays
      var _callbacks = {};

      //---- listener arrays
      var _bindListeners = {};

      //---- sequence id for callback identify
      var _promiseId = 0;
      //
      var _Request = function(args){
        this._args = args;
        this._id = ++_promiseId;
        this._response = undefined;
      };

      _Request.prototype.response = function() {
        return this._response;
      };

      _Request.prototype.send = function(){
        var deferred = $q.defer();
        _callbacks[this._id] = deferred;
        this._args.id = this._id;
        _dataStream.send(JSON.stringify(this._args));
        var me = this;
        return deferred.promise.then(function(response) {
          me._response = response;
          return response;
        }).catch(function(err){
          me._error = err;
          return err;
        });
      };

      var funcInit = function(){
        if(_dataStream !== undefined){
          _dataStream.onClose(function(){
            console.log('close');
            var listener = _bindListeners['close'];
            if(listener !== undefined){
              listener(arguments);
            }
          });
          _dataStream.onError(function(){
            console.log('error');
            var listener = _bindListeners['error'];
            if(listener !== undefined){
              listener(arguments);
            }
          });
          _dataStream.onMessage(function(message) {
            var data = message.data;
            //TODO: check json type
            data = JSON.parse(data);
            var id = data.id;
            if(id !== undefined){
              //event callback
              var callback = _callbacks[id];

              if(callback !== undefined){
                delete _callbacks[id];
                callback.resolve(data);
              }else{
                //TODO: no callback handle;
              }
            }else{
              //mybe boardcast callback
              var channel = data.channel;
              if(channel){
                var listener = _bindListeners[channel];
                if(listener !== undefined){
                  listener(data);
                }
              }else{
                //TODO: unknown message;
              }
            }

          });
        }else{
          console.log('Fetal~ DataStream Not Defined!');
        }
      };

      return {
        init: function(options){
          options = options || {};
          for(var k in options){
              _options[k] = options[k];
          }
          _dataStream = $websocket(_options.endpoint, _options.channels);
          funcInit();
        },
        reconnect: function(){
          if(_dataStream){
            _dataStream.reconnect();
          }
        },
        bind: function(channel, func){
          _bindListeners[channel] = func;
        },
        unbind: function(channel){
          delete _bindListeners[channel];
        },
        Request: _Request
      }

   }]);

})();
```

