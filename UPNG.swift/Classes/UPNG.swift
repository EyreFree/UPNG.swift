
import UIKit
import EFFoundation
import WebKit

public class UPNG {
    
    public static let shared: UPNG = UPNG()
    
    private static var dictionary: [String: WKWebView] = [:]
    
    public init() {
        
    }
    
    private func getWebViewWith(tag: String, createIfNeeded: Bool, completion: ((WKWebView?) -> Void)?) {
        if let webView = UPNG.dictionary[tag] {
            completion?(webView)
        } else if createIfNeeded {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tempView: WKWebView = WKWebView()
                tempView.isHidden = false
                self.setWebViewWith(tag: tag, webView: tempView)
                completion?(tempView)
            }
        }
    }
    
    private func removeWebViewWith(tag: String) {
        setWebViewWith(tag: tag, webView: nil)
    }
    
    private func setWebViewWith(tag: String, webView: WKWebView?) {
        if let webView = webView {
            UPNG.dictionary[tag] = webView
        } else {
            UPNG.dictionary.removeValue(forKey: tag)
        }
    }
    
    /// UPNG.com/optimize.
    /// - Parameters:
    ///   - imageUrl: imageUrl.
    ///   - compressionLevel: compressionLevel for Lossy Gif, 0 - no color but less size, 1000 - full color and full size, range [0, 1000], default 200.
    ///   - timeout: force completion with nil after seconds, to avoid dead cycle, default 20s.
    ///   - completion: completion.
    /// - Returns: Void..
    public func optimize(imageData: Data, compressionLevel: Int = 200, timeout: TimeInterval = 20, completion: ((Data?, Error?) -> Void)?) {
        let webViewTag: String = "\(Date().timeIntervalSince1970)"
        getWebViewWith(tag: webViewTag, createIfNeeded: true) { [weak self] webView in
            guard let self = self else { return }
            
            if let webView = webView {
                let timeoutDate: Date = Date().addingTimeInterval(timeout)
                func customCompletion(_ imageData: Data?, _ error: Error?) {
                    self.removeWebViewWith(tag: webViewTag)
                    completion?(imageData, error)
                }
                self.loadUPNGPage(webView: webView) { [weak self] success in
                    guard let self = self else { return }
                    
                    if success {
                        self.waitingPageLoading(webView: webView, timeoutDate: timeoutDate) { [weak self] result, error in
                            guard let self = self else { return }
                            
                            if true == result {
                                self.waitingSetCompressionLevel(webView: webView, value: compressionLevel) { [weak self] result, error in
                                    guard let self = self else { return }
                                    
                                    if true == result {
                                        let imageBase64String: String = imageData.base64EncodedString()
                                        self.waitingSetImageBase64String(webView: webView, imageBase64String: imageBase64String) { [weak self] result, error in
                                            guard let self = self else { return }
                                            
                                            if true == result {
                                                self.waitingInputButtonClicked(webView: webView) { [weak self] error in
                                                    guard let self = self else { return }
                                                    
                                                    if let error = error {
                                                        printLog("waitingInputButtonClicked: \(error.localizedDescription)")
                                                        customCompletion(nil, error)
                                                    } else {
                                                        self.waitingOutImageState(webView: webView, timeoutDate: timeoutDate) { [weak self] result, error in
                                                            guard let self = self else { return }
                                                            
                                                            if true == result {
                                                                self.waitingGetOutImageBase64String(webView: webView, timeoutDate: timeoutDate) { [weak self] imageBase64String, error in
                                                                    guard let _ = self else { return }
                                                                    
                                                                    if let imageBase64String = imageBase64String, imageBase64String.isEmpty == false,
                                                                        let imageData = Data(base64Encoded: imageBase64String, options: .ignoreUnknownCharacters) {
                                                                        customCompletion(imageData, error)
                                                                    } else {
                                                                        customCompletion(nil, error)
                                                                    }
                                                                }
                                                            } else {
                                                                printLog("waitingOptimizeState failed: \(error?.localizedDescription ?? "")")
                                                                customCompletion(nil, error)
                                                            }
                                                        }
                                                    }
                                                }
                                            } else {
                                                printLog("waitingSetImageBase64String failed: \(error?.localizedDescription ?? "")")
                                                customCompletion(nil, error)
                                            }
                                        }
                                    } else {
                                        printLog("waitingSetCompressionLevel failed: \(error?.localizedDescription ?? "")")
                                        customCompletion(nil, error)
                                    }
                                }
                            } else {
                                printLog("waitingPageLoading failed: \(error?.localizedDescription ?? "")")
                                customCompletion(nil, error)
                            }
                        }
                    } else {
                        customCompletion(nil, "loadUPNGPage failed")
                    }
                }
            } else {
                completion?(nil, "Create webView failed")
            }
        }
    }
    
    private func loadUPNGPage(webView: WKWebView, completion: ((Bool) -> Void)?) {
        printLog("loadUPNGPage")
        DispatchQueue.main.async { [weak self] in
            guard let _ = self else { return }
            
            // printLog("loadUPNGPage: \(url)")
            webView.loadHTMLString(UPNG.htmlString, baseURL: nil)
            completion?(true)
        }
    }
    
    private func waitingPageLoading(webView: WKWebView, timeoutDate: Date, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingPageLoading")
        if Date() >= timeoutDate {
            completion?(false, "Timeout")
            return
        }
        
        let javascript: String = "document.getElementById('base64-textarea') != null && document.getElementById('base64-result-textarea') != null && document.getElementById('base64-button') != null && document.getElementById('eRNG') != null"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion?(false, error)
                } else if let result = data as? Bool, result == true {
                    completion?(true, nil)
                } else {
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
                        guard let self = self else { return }
                        
                        self.waitingPageLoading(webView: webView, timeoutDate: timeoutDate, completion: completion)
                    }
                }
            }
        }
    }
    
    private func waitingSetCompressionLevel(webView: WKWebView, value: Int, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingSetCompressionLevel")
        if value == 200 {
            completion?(true, nil)
        } else {
            let javascript: String = "document.getElementById('eRNG').value = \(value); moveQual(\(value));"
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                webView.evaluateJavaScript(javascript) { [weak self] data, error in
                    guard let _ = self else { return }
                    
                    if let error = error {
                        completion?(false, error)
                    } else if let result = data as? Int, result == value {
                        completion?(true, nil)
                    } else {
                        completion?(false, "evaluateJavaScript result not true")
                    }
                }
            }
        }
    }
    
    private func waitingSetImageBase64String(webView: WKWebView, imageBase64String: String, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingSetImageBase64String")
        let javascript: String = "document.getElementById('base64-textarea').value = '\(imageBase64String)'"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let _ = self else { return }
                
                if let error = error {
                    completion?(false, error)
                } else if let result = data as? String, result == imageBase64String {
                    completion?(true, nil)
                } else {
                    completion?(false, "evaluateJavaScript result not true")
                }
            }
        }
    }
    
    private func waitingInputButtonClicked(webView: WKWebView, completion: ((Error?) -> Void)?) {
        printLog("waitingInputButtonClicked")
        let javascript: String = "document.getElementById('base64-button').click();"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let _ = self else { return }
                
                completion?(error)
            }
        }
    }
    
    private func waitingOutImageState(webView: WKWebView, timeoutDate: Date, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingOutImageState")
        if Date() >= timeoutDate {
            completion?(false, "Timeout")
            return
        }
        
        let javascript: String = "document.getElementById('base64-result-textarea').value.length > 0"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion?(false, error)
                } else if let result = data as? Bool, result == true {
                    completion?(true, nil)
                } else {
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
                        guard let self = self else { return }
                        
                        self.waitingOutImageState(webView: webView, timeoutDate: timeoutDate, completion: completion)
                    }
                }
            }
        }
    }
    
    private func waitingGetOutImageBase64String(webView: WKWebView, timeoutDate: Date, completion: ((String?, Error?) -> Void)?) {
        printLog("waitingGetOutImageBase64String")
        if Date() >= timeoutDate {
            completion?(nil, "Timeout")
            return
        }
        
        let javascript: String = "document.getElementById('base64-result-textarea').value"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let _ = self else { return }
                
                if let error = error {
                    completion?(nil, error)
                } else if let base64String = data as? String, base64String.isEmpty == false {
                    let base64DataString: String = base64String.removePrefix(string: "data:application/octet-stream;base64,")
                    completion?(base64DataString, nil)
                } else {
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
                        guard let self = self else { return }
                        
                        self.waitingGetOutImageBase64String(webView: webView, timeoutDate: timeoutDate, completion: completion)
                    }
                }
            }
        }
    }
}

// MARK: - htmlString
extension UPNG {
    
    fileprivate static let htmlString: String = """
    <!DOCTYPE HTML>
    <html>

    <head>
      
      <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());  gtag('config', 'UA-4249565-44');
      </script>

        <meta charset=\"utf-8\" />
        <title>UPNG: fast PNG minifier</title>
        
        <meta name=\"description\" content=\"Fast and simple PNG minfier (compressor).\" />
        <style type=\"text/css\">
          .divide{ height: calc(100%); display: flex;flex-direction: column;}
          .divide p{flex: auto; border: 1px solid #ccc;  }
          .divide textarea { width: 100%; margin: 0; padding: 0; border-width: 0; }
        </style>

        <!--
        <link rel='stylesheet' id='casper-google-fonts-css'  href='//fonts.googleapis.com/css?family=Noto+Serif%3A400%2C700%2C400italic%7COpen+Sans%3A700%2C400&#038;ver=4.0.1' type='text/css' media='all' />
        <script src=\"js/ext.js\"></script>

        <script src=\"js/UPNG.js\"></script>
        <script src=\"js/UZIP.js\"></script>
        <link type=\"text/css\" rel=\"stylesheet\" href=\"style.css\" />
        -->

        <!-- style.css -->
        <style type=\"text/css\">
        * {  margin:0;  padding:0;
            font-family: \"Open Sans\", sans-serif;
        }

        body {
            color:#3a3a3a;
            background-color:#f6f8fa;
            user-select: none;
        }
        
        h1 {
            font-size: 2em;
            padding-top: 0.3em;
            padding-bottom: 0.5em;
        }
        

        header {
            color: white;
            height:170px;
            text-align:center;
            background: linear-gradient(#4fa0eb, #9656d9);
        }
        header a {
            color: white;
            font-weight:bold;
            margin-right:14px;
        }
        header iframe {  vertical-align:middle;  }
        
        .foot {
            background-repeat: repeat-x;
            background-position: center bottom;
            background-size: 200px 50px;
            padding: 0.5em 0 1.1em 0;
        }
        
        footer {
            font-size:1.5em;
            height:50px;
            width:660px;
            padding: 0.3em 1em 0 1em;
            background-color:#f6f8fa;
            box-shadow: 0px 3px 9px rgba(0,0,0,0.55);
            border-radius:1em;
            margin: 0 auto;
        }
        
        canvas {
            float:left;
            position:absolute;
        }
        
        button {
            font-size: 1em;
            background-color: #9656d9;
            color: white;
            border: none;
            padding: 0.2em 0.7em;
            margin-left: 1em;
            font-weight:bold;
            cursor:pointer;
            border-radius: 0.3em;
        }

        #main {
            margin:0 auto;
            overflow-x:visible;
        }
        
        #lcont {
            width: 500px;
            float:left;
        }
        #list {
            overflow-y:scroll;
        }
        #list::-webkit-scrollbar {
          width: 10px;
          background: rgba(0,0,0,0);
        }
        #list::-webkit-scrollbar-thumb {
            background: rgba(0,0,0, 0.2 );
            margin:2px;
        }
        
        .item {
            padding: 0.5em;
            cursor:pointer;
        }
        
        .active {
            background-color: rgba(0,100,190,0.15);
        }
        
        .item .fname {
            display:inline-block;
            width:8.5em;
        }
        .item span {
            display:inline-block;
            width:4.5em;
            text-align:right;
        }
        
        #bunny {
            transition: transform .2s ease-out;
            filter:     drop-shadow(5px 7px 5px rgba(0,0,0,0.4));
            
            position: absolute; width:94px; top:20px; margin-left:500px; cursor:pointer;
        }
        #bunny:hover {
            transform: translate(0, -10px);
        }
        </style>
        
        <!-- UZIP.js -->
        <script type=\"text/javascript\">
        var UZIP = {};
        if(typeof module == \"object\") module.exports = UZIP;


        UZIP[\"parse\"] = function(buf, onlyNames)    // ArrayBuffer
        {
            var rUs = UZIP.bin.readUshort, rUi = UZIP.bin.readUint, o = 0, out = {};
            var data = new Uint8Array(buf);
            var eocd = data.length-4;
            
            while(rUi(data, eocd)!=0x06054b50) eocd--;
            
            var o = eocd;
            o+=4;    // sign  = 0x06054b50
            o+=4;  // disks = 0;
            var cnu = rUs(data, o);  o+=2;
            var cnt = rUs(data, o);  o+=2;
                    
            var csize = rUi(data, o);  o+=4;
            var coffs = rUi(data, o);  o+=4;
            
            o = coffs;
            for(var i=0; i<cnu; i++)
            {
                var sign = rUi(data, o);  o+=4;
                o += 4;  // versions;
                o += 4;  // flag + compr
                o += 4;  // time
                
                var crc32 = rUi(data, o);  o+=4;
                var csize = rUi(data, o);  o+=4;
                var usize = rUi(data, o);  o+=4;
                
                var nl = rUs(data, o), el = rUs(data, o+2), cl = rUs(data, o+4);  o += 6;  // name, extra, comment
                o += 8;  // disk, attribs
                
                var roff = rUi(data, o);  o+=4;
                o += nl + el + cl;
                
                UZIP._readLocal(data, roff, out, csize, usize, onlyNames);
            }
            //console.log(out);
            return out;
        }

        UZIP._readLocal = function(data, o, out, csize, usize, onlyNames)
        {
            var rUs = UZIP.bin.readUshort, rUi = UZIP.bin.readUint;
            var sign  = rUi(data, o);  o+=4;
            var ver   = rUs(data, o);  o+=2;
            var gpflg = rUs(data, o);  o+=2;
            //if((gpflg&8)!=0) throw \"unknown sizes\";
            var cmpr  = rUs(data, o);  o+=2;
            
            var time  = rUi(data, o);  o+=4;
            
            var crc32 = rUi(data, o);  o+=4;
            //var csize = rUi(data, o);  o+=4;
            //var usize = rUi(data, o);  o+=4;
            o+=8;
                
            var nlen  = rUs(data, o);  o+=2;
            var elen  = rUs(data, o);  o+=2;
                
            var name =  UZIP.bin.readUTF8(data, o, nlen);  o+=nlen;  //console.log(name);
            o += elen;
                    
            //console.log(sign.toString(16), ver, gpflg, cmpr, crc32.toString(16), \"csize, usize\", csize, usize, nlen, elen, name, o);
            if(onlyNames) {  out[name]={size:usize, csize:csize};  return;  }
            var file = new Uint8Array(data.buffer, o);
            if(false) {}
            else if(cmpr==0) out[name] = new Uint8Array(file.buffer.slice(o, o+csize));
            else if(cmpr==8) {
                var buf = new Uint8Array(usize);  UZIP.inflateRaw(file, buf);
                /*var nbuf = pako[\"inflateRaw\"](file);
                if(usize>8514000) {
                    //console.log(PUtils.readASCII(buf , 8514500, 500));
                    //console.log(PUtils.readASCII(nbuf, 8514500, 500));
                }
                for(var i=0; i<buf.length; i++) if(buf[i]!=nbuf[i]) {  console.log(buf.length, nbuf.length, usize, i);  throw \"e\";  }
                */
                out[name] = buf;
            }
            else throw \"unknown compression method: \"+cmpr;
        }

        UZIP.inflateRaw = function(file, buf) {  return UZIP.F.inflate(file, buf);  }
        UZIP.inflate    = function(file, buf) {
            var CMF = file[0], FLG = file[1];
            var CM = (CMF&15), CINFO = (CMF>>>4);
            //console.log(CM, CINFO,CMF,FLG);
            return UZIP.inflateRaw(new Uint8Array(file.buffer, file.byteOffset+2, file.length-6), buf);
        }
        UZIP.deflate    = function(data, opts/*, buf, off*/) {
            if(opts==null) opts={level:6};
            var off=0, buf=new Uint8Array(50+Math.floor(data.length*1.1));
            buf[off]=120;  buf[off+1]=156;  off+=2;
            off = UZIP.F.deflateRaw(data, buf, off, opts.level);
            var crc = UZIP.adler(data, 0, data.length);
            buf[off+0]=((crc>>>24)&255);
            buf[off+1]=((crc>>>16)&255);
            buf[off+2]=((crc>>> 8)&255);
            buf[off+3]=((crc>>> 0)&255);
            return new Uint8Array(buf.buffer, 0, off+4);
        }
        UZIP.deflateRaw = function(data, opts) {
            if(opts==null) opts={level:6};
            var buf=new Uint8Array(50+Math.floor(data.length*1.1));
            var off = UZIP.F.deflateRaw(data, buf, off, opts.level);
            return new Uint8Array(buf.buffer, 0, off);
        }


        UZIP.encode = function(obj, noCmpr) {
            if(noCmpr==null) noCmpr=false;
            var tot = 0, wUi = UZIP.bin.writeUint, wUs = UZIP.bin.writeUshort;
            var zpd = {};
            for(var p in obj) {  var cpr = !UZIP._noNeed(p) && !noCmpr, buf = obj[p], crc = UZIP.crc.crc(buf,0,buf.length);
                zpd[p] = {  cpr:cpr, usize:buf.length, crc:crc, file: (cpr ? UZIP.deflateRaw(buf) : buf)  };  }
            
            for(var p in zpd) tot += zpd[p].file.length + 30 + 46 + 2*UZIP.bin.sizeUTF8(p);
            tot +=  22;
            
            var data = new Uint8Array(tot), o = 0;
            var fof = []
            
            for(var p in zpd) {
                var file = zpd[p];  fof.push(o);
                o = UZIP._writeHeader(data, o, p, file, 0);
            }
            var i=0, ioff = o;
            for(var p in zpd) {
                var file = zpd[p];  fof.push(o);
                o = UZIP._writeHeader(data, o, p, file, 1, fof[i++]);
            }
            var csize = o-ioff;
            
            wUi(data, o, 0x06054b50);  o+=4;
            o += 4;  // disks
            wUs(data, o, i);  o += 2;
            wUs(data, o, i);  o += 2;    // number of c d records
            wUi(data, o, csize);  o += 4;
            wUi(data, o, ioff );  o += 4;
            o += 2;
            return data.buffer;
        }
        // no need to compress .PNG, .ZIP, .JPEG ....
        UZIP._noNeed = function(fn) {  var ext = fn.split(\".\").pop().toLowerCase();  return \"png,jpg,jpeg,zip\".indexOf(ext)!=-1;  }

        UZIP._writeHeader = function(data, o, p, obj, t, roff)
        {
            var wUi = UZIP.bin.writeUint, wUs = UZIP.bin.writeUshort;
            var file = obj.file;
            
            wUi(data, o, t==0 ? 0x04034b50 : 0x02014b50);  o+=4; // sign
            if(t==1) o+=2;  // ver made by
            wUs(data, o, 20);  o+=2;    // ver
            wUs(data, o,  0);  o+=2;    // gflip
            wUs(data, o,  obj.cpr?8:0);  o+=2;    // cmpr
                
            wUi(data, o,  0);  o+=4;    // time
            wUi(data, o, obj.crc);  o+=4;    // crc32
            wUi(data, o, file.length);  o+=4;    // csize
            wUi(data, o, obj.usize);  o+=4;    // usize
                
            wUs(data, o, UZIP.bin.sizeUTF8(p));  o+=2;    // nlen
            wUs(data, o, 0);  o+=2;    // elen
            
            if(t==1) {
                o += 2;  // comment length
                o += 2;  // disk number
                o += 6;  // attributes
                wUi(data, o, roff);  o+=4;    // usize
            }
            var nlen = UZIP.bin.writeUTF8(data, o, p);  o+= nlen;
            if(t==0) {  data.set(file, o);  o += file.length;  }
            return o;
        }





        UZIP.crc = {
            table : ( function() {
               var tab = new Uint32Array(256);
               for (var n=0; n<256; n++) {
                    var c = n;
                    for (var k=0; k<8; k++) {
                        if (c & 1)  c = 0xedb88320 ^ (c >>> 1);
                        else        c = c >>> 1;
                    }
                    tab[n] = c;  }
                return tab;  })(),
            update : function(c, buf, off, len) {
                for (var i=0; i<len; i++)  c = UZIP.crc.table[(c ^ buf[off+i]) & 0xff] ^ (c >>> 8);
                return c;
            },
            crc : function(b,o,l)  {  return UZIP.crc.update(0xffffffff,b,o,l) ^ 0xffffffff;  }
        }
        UZIP.adler = function(data,o,len) {
            var a = 1, b = 0;
            var off = o, end=o+len;
            while(off<end) {
                var eend = Math.min(off+5552, end);
                while(off<eend) {
                    a += data[off++];
                    b += a;
                }
                a=a%65521;
                b=b%65521;
            }
            return (b << 16) | a;
        }

        UZIP.bin = {
            readUshort : function(buff,p)  {  return (buff[p]) | (buff[p+1]<<8);  },
            writeUshort: function(buff,p,n){  buff[p] = (n)&255;  buff[p+1] = (n>>8)&255;  },
            readUint   : function(buff,p)  {  return (buff[p+3]*(256*256*256)) + ((buff[p+2]<<16) | (buff[p+1]<< 8) | buff[p]);  },
            writeUint  : function(buff,p,n){  buff[p]=n&255;  buff[p+1]=(n>>8)&255;  buff[p+2]=(n>>16)&255;  buff[p+3]=(n>>24)&255;  },
            readASCII  : function(buff,p,l){  var s = \"\";  for(var i=0; i<l; i++) s += String.fromCharCode(buff[p+i]);  return s;    },
            writeASCII : function(data,p,s){  for(var i=0; i<s.length; i++) data[p+i] = s.charCodeAt(i);  },
            pad : function(n) { return n.length < 2 ? \"0\" + n : n; },
            readUTF8 : function(buff, p, l) {
                var s = \"\", ns;
                for(var i=0; i<l; i++) s += \"%\" + UZIP.bin.pad(buff[p+i].toString(16));
                try {  ns = decodeURIComponent(s); }
                catch(e) {  return UZIP.bin.readASCII(buff, p, l);  }
                return  ns;
            },
            writeUTF8 : function(buff, p, str) {
                var strl = str.length, i=0;
                for(var ci=0; ci<strl; ci++)
                {
                    var code = str.charCodeAt(ci);
                    if     ((code&(0xffffffff-(1<< 7)+1))==0) {  buff[p+i] = (     code     );  i++;  }
                    else if((code&(0xffffffff-(1<<11)+1))==0) {  buff[p+i] = (192|(code>> 6));  buff[p+i+1] = (128|((code>> 0)&63));  i+=2;  }
                    else if((code&(0xffffffff-(1<<16)+1))==0) {  buff[p+i] = (224|(code>>12));  buff[p+i+1] = (128|((code>> 6)&63));  buff[p+i+2] = (128|((code>>0)&63));  i+=3;  }
                    else if((code&(0xffffffff-(1<<21)+1))==0) {  buff[p+i] = (240|(code>>18));  buff[p+i+1] = (128|((code>>12)&63));  buff[p+i+2] = (128|((code>>6)&63));  buff[p+i+3] = (128|((code>>0)&63)); i+=4;  }
                    else throw \"e\";
                }
                return i;
            },
            sizeUTF8 : function(str) {
                var strl = str.length, i=0;
                for(var ci=0; ci<strl; ci++)
                {
                    var code = str.charCodeAt(ci);
                    if     ((code&(0xffffffff-(1<< 7)+1))==0) {  i++ ;  }
                    else if((code&(0xffffffff-(1<<11)+1))==0) {  i+=2;  }
                    else if((code&(0xffffffff-(1<<16)+1))==0) {  i+=3;  }
                    else if((code&(0xffffffff-(1<<21)+1))==0) {  i+=4;  }
                    else throw \"e\";
                }
                return i;
            }
        }





        UZIP.F = {};

        UZIP.F.deflateRaw = function(data, out, opos, lvl) {
            var opts = [
            /*
                 ush good_length; /* reduce lazy search above this match length
                 ush max_lazy;    /* do not perform lazy search above this match length
                 ush nice_length; /* quit search above this match length
            */
            /*      good lazy nice chain */
            /* 0 */ [ 0,   0,   0,    0,0],  /* store only */
            /* 1 */ [ 4,   4,   8,    4,0], /* max speed, no lazy matches */
            /* 2 */ [ 4,   5,  16,    8,0],
            /* 3 */ [ 4,   6,  16,   16,0],

            /* 4 */ [ 4,  10,  16,   32,0],  /* lazy matches */
            /* 5 */ [ 8,  16,  32,   32,0],
            /* 6 */ [ 8,  16, 128,  128,0],
            /* 7 */ [ 8,  32, 128,  256,0],
            /* 8 */ [32, 128, 258, 1024,1],
            /* 9 */ [32, 258, 258, 4096,1]]; /* max compression */
            
            var opt = opts[lvl];
            
            
            var U = UZIP.F.U, goodIndex = UZIP.F._goodIndex, hash = UZIP.F._hash, putsE = UZIP.F._putsE;
            var i = 0, pos = opos<<3, cvrd = 0, dlen = data.length;
            
            if(lvl==0) {
                while(i<dlen) {   var len = Math.min(0xffff, dlen-i);
                    putsE(out, pos, (i+len==dlen ? 1 : 0));  pos = UZIP.F._copyExact(data, i, len, out, pos+8);  i += len;  }
                return pos>>>3;
            }

            var lits = U.lits, strt=U.strt, prev=U.prev, li=0, lc=0, bs=0, ebits=0, c=0, nc=0;  // last_item, literal_count, block_start
            if(dlen>2) {  nc=UZIP.F._hash(data,0);  strt[nc]=0;  }
            var nmch=0,nmci=0;
            
            for(i=0; i<dlen; i++)  {
                c = nc;
                //*
                if(i+1<dlen-2) {
                    nc = UZIP.F._hash(data, i+1);
                    var ii = ((i+1)&0x7fff);
                    prev[ii]=strt[nc];
                    strt[nc]=ii;
                } //*/
                if(cvrd<=i) {
                    if((li>14000 || lc>26697) && (dlen-i)>100) {
                        if(cvrd<i) {  lits[li]=i-cvrd;  li+=2;  cvrd=i;  }
                        pos = UZIP.F._writeBlock(((i==dlen-1) || (cvrd==dlen))?1:0, lits, li, ebits, data,bs,i-bs, out, pos);  li=lc=ebits=0;  bs=i;
                    }
                    
                    var mch = 0;
                    //if(nmci==i) mch= nmch;  else
                    if(i<dlen-2) mch = UZIP.F._bestMatch(data, i, prev, c, Math.min(opt[2],dlen-i), opt[3]);
                    /*
                    if(mch!=0 && opt[4]==1 && (mch>>>16)<opt[1] && i+1<dlen-2) {
                        nmch = UZIP.F._bestMatch(data, i+1, prev, nc, opt[2], opt[3]);  nmci=i+1;
                        //var mch2 = UZIP.F._bestMatch(data, i+2, prev, nnc);  //nmci=i+1;
                        if((nmch>>>16)>(mch>>>16)) mch=0;
                    }//*/
                    var len = mch>>>16, dst = mch&0xffff;  //if(i-dst<0) throw \"e\";
                    if(mch!=0) {
                        var len = mch>>>16, dst = mch&0xffff;  //if(i-dst<0) throw \"e\";
                        var lgi = goodIndex(len, U.of0);  U.lhst[257+lgi]++;
                        var dgi = goodIndex(dst, U.df0);  U.dhst[    dgi]++;  ebits += U.exb[lgi] + U.dxb[dgi];
                        lits[li] = (len<<23)|(i-cvrd);  lits[li+1] = (dst<<16)|(lgi<<8)|dgi;  li+=2;
                        cvrd = i + len;
                    }
                    else {    U.lhst[data[i]]++;  }
                    lc++;
                }
            }
            if(bs!=i || data.length==0) {
                if(cvrd<i) {  lits[li]=i-cvrd;  li+=2;  cvrd=i;  }
                pos = UZIP.F._writeBlock(1, lits, li, ebits, data,bs,i-bs, out, pos);  li=0;  lc=0;  li=lc=ebits=0;  bs=i;
            }
            while((pos&7)!=0) pos++;
            return pos>>>3;
        }
        UZIP.F._bestMatch = function(data, i, prev, c, nice, chain) {
            var ci = (i&0x7fff), pi=prev[ci];
            //console.log(\"----\", i);
            var dif = ((ci-pi + (1<<15)) & 0x7fff);  if(pi==ci || c!=UZIP.F._hash(data,i-dif)) return 0;
            var tl=0, td=0;  // top length, top distance
            var dlim = Math.min(0x7fff, i);
            while(dif<=dlim && --chain!=0 && pi!=ci /*&& c==UZIP.F._hash(data,i-dif)*/) {
                if(tl==0 || (data[i+tl]==data[i+tl-dif])) {
                    var cl = UZIP.F._howLong(data, i, dif);
                    if(cl>tl) {
                        tl=cl;  td=dif;  if(tl>=nice) break;    //*
                        if(dif+2<cl) cl = dif+2;
                        var maxd = 0; // pi does not point to the start of the word
                        for(var j=0; j<cl-2; j++) {
                            var ei =  (i-dif+j+ (1<<15)) & 0x7fff;
                            var li = prev[ei];
                            var curd = (ei-li + (1<<15)) & 0x7fff;
                            if(curd>maxd) {  maxd=curd;  pi = ei; }
                        }  //*/
                    }
                }
                
                ci=pi;  pi = prev[ci];
                dif += ((ci-pi + (1<<15)) & 0x7fff);
            }
            return (tl<<16)|td;
        }
        UZIP.F._howLong = function(data, i, dif) {
            if(data[i]!=data[i-dif] || data[i+1]!=data[i+1-dif] || data[i+2]!=data[i+2-dif]) return 0;
            var oi=i, l = Math.min(data.length, i+258);  i+=3;
            //while(i+4<l && data[i]==data[i-dif] && data[i+1]==data[i+1-dif] && data[i+2]==data[i+2-dif] && data[i+3]==data[i+3-dif]) i+=4;
            while(i<l && data[i]==data[i-dif]) i++;
            return i-oi;
        }
        UZIP.F._hash = function(data, i) {
            return (((data[i]<<8) | data[i+1])+(data[i+2]<<4))&0xffff;
            //var hash_shift = 0, hash_mask = 255;
            //var h = data[i+1] % 251;
            //h = (((h << 8) + data[i+2]) % 251);
            //h = (((h << 8) + data[i+2]) % 251);
            //h = ((h<<hash_shift) ^ (c) ) & hash_mask;
            //return h | (data[i]<<8);
            //return (data[i] | (data[i+1]<<8));
        }
        //UZIP.___toth = 0;
        UZIP.saved = 0;
        UZIP.F._writeBlock = function(BFINAL, lits, li, ebits, data,o0,l0, out, pos) {
            var U = UZIP.F.U, putsF = UZIP.F._putsF, putsE = UZIP.F._putsE;
            
            //*
            var T, ML, MD, MH, numl, numd, numh, lset, dset;  U.lhst[256]++;
            T = UZIP.F.getTrees(); ML=T[0]; MD=T[1]; MH=T[2]; numl=T[3]; numd=T[4]; numh=T[5]; lset=T[6]; dset=T[7];
            
            var cstSize = (((pos+3)&7)==0 ? 0 : 8-((pos+3)&7)) + 32 + (l0<<3);
            var fxdSize = ebits + UZIP.F.contSize(U.fltree, U.lhst) + UZIP.F.contSize(U.fdtree, U.dhst);
            var dynSize = ebits + UZIP.F.contSize(U.ltree , U.lhst) + UZIP.F.contSize(U.dtree , U.dhst);
            dynSize    += 14 + 3*numh + UZIP.F.contSize(U.itree, U.ihst) + (U.ihst[16]*2 + U.ihst[17]*3 + U.ihst[18]*7);
            
            for(var j=0; j<286; j++) U.lhst[j]=0;   for(var j=0; j<30; j++) U.dhst[j]=0;   for(var j=0; j<19; j++) U.ihst[j]=0;
            //*/
            var BTYPE = (cstSize<fxdSize && cstSize<dynSize) ? 0 : ( fxdSize<dynSize ? 1 : 2 );
            putsF(out, pos, BFINAL);  putsF(out, pos+1, BTYPE);  pos+=3;
            
            var opos = pos;
            if(BTYPE==0) {
                while((pos&7)!=0) pos++;
                pos = UZIP.F._copyExact(data, o0, l0, out, pos);
            }
            else {
                var ltree, dtree;
                if(BTYPE==1) {  ltree=U.fltree;  dtree=U.fdtree;  }
                if(BTYPE==2) {
                    UZIP.F.makeCodes(U.ltree, ML);  UZIP.F.revCodes(U.ltree, ML);
                    UZIP.F.makeCodes(U.dtree, MD);  UZIP.F.revCodes(U.dtree, MD);
                    UZIP.F.makeCodes(U.itree, MH);  UZIP.F.revCodes(U.itree, MH);
                    
                    ltree = U.ltree;  dtree = U.dtree;
                    
                    putsE(out, pos,numl-257);  pos+=5;  // 286
                    putsE(out, pos,numd-  1);  pos+=5;  // 30
                    putsE(out, pos,numh-  4);  pos+=4;  // 19
                    
                    for(var i=0; i<numh; i++) putsE(out, pos+i*3, U.itree[(U.ordr[i]<<1)+1]);   pos+=3* numh;
                    pos = UZIP.F._codeTiny(lset, U.itree, out, pos);
                    pos = UZIP.F._codeTiny(dset, U.itree, out, pos);
                }
                
                var off=o0;
                for(var si=0; si<li; si+=2) {
                    var qb=lits[si], len=(qb>>>23), end = off+(qb&((1<<23)-1));
                    while(off<end) pos = UZIP.F._writeLit(data[off++], ltree, out, pos);
                    
                    if(len!=0) {
                        var qc = lits[si+1], dst=(qc>>16), lgi=(qc>>8)&255, dgi=(qc&255);
                        pos = UZIP.F._writeLit(257+lgi, ltree, out, pos);
                        putsE(out, pos, len-U.of0[lgi]);  pos+=U.exb[lgi];
                        
                        pos = UZIP.F._writeLit(dgi, dtree, out, pos);
                        putsF(out, pos, dst-U.df0[dgi]);  pos+=U.dxb[dgi];  off+=len;
                    }
                }
                pos = UZIP.F._writeLit(256, ltree, out, pos);
            }
            //console.log(pos-opos, fxdSize, dynSize, cstSize);
            return pos;
        }
        UZIP.F._copyExact = function(data,off,len,out,pos) {
            var p8 = (pos>>>3);
            out[p8]=(len);  out[p8+1]=(len>>>8);  out[p8+2]=255-out[p8];  out[p8+3]=255-out[p8+1];  p8+=4;
            out.set(new Uint8Array(data.buffer, off, len), p8);
            //for(var i=0; i<len; i++) out[p8+i]=data[off+i];
            return pos + ((len+4)<<3);
        }
        /*
            Interesting facts:
            - decompressed block can have bytes, which do not occur in a Huffman tree (copied from the previous block by reference)
        */

        UZIP.F.getTrees = function() {
            var U = UZIP.F.U;
            var ML = UZIP.F._hufTree(U.lhst, U.ltree, 15);
            var MD = UZIP.F._hufTree(U.dhst, U.dtree, 15);
            var lset = [], numl = UZIP.F._lenCodes(U.ltree, lset);
            var dset = [], numd = UZIP.F._lenCodes(U.dtree, dset);
            for(var i=0; i<lset.length; i+=2) U.ihst[lset[i]]++;
            for(var i=0; i<dset.length; i+=2) U.ihst[dset[i]]++;
            var MH = UZIP.F._hufTree(U.ihst, U.itree,  7);
            var numh = 19;  while(numh>4 && U.itree[(U.ordr[numh-1]<<1)+1]==0) numh--;
            return [ML, MD, MH, numl, numd, numh, lset, dset];
        }
        UZIP.F.getSecond= function(a) {  var b=[];  for(var i=0; i<a.length; i+=2) b.push  (a[i+1]);  return b;  }
        UZIP.F.nonZero  = function(a) {  var b= \"\";  for(var i=0; i<a.length; i+=2) if(a[i+1]!=0)b+=(i>>1)+\",\";  return b;  }
        UZIP.F.contSize = function(tree, hst) {  var s=0;  for(var i=0; i<hst.length; i++) s+= hst[i]*tree[(i<<1)+1];  return s;  }
        UZIP.F._codeTiny = function(set, tree, out, pos) {
            for(var i=0; i<set.length; i+=2) {
                var l = set[i], rst = set[i+1];  //console.log(l, pos, tree[(l<<1)+1]);
                pos = UZIP.F._writeLit(l, tree, out, pos);
                var rsl = l==16 ? 2 : (l==17 ? 3 : 7);
                if(l>15) {  UZIP.F._putsE(out, pos, rst, rsl);  pos+=rsl;  }
            }
            return pos;
        }
        UZIP.F._lenCodes = function(tree, set) {
            var len=tree.length;  while(len!=2 && tree[len-1]==0) len-=2;  // when no distances, keep one code with length 0
            for(var i=0; i<len; i+=2) {
                var l = tree[i+1], nxt = (i+3<len ? tree[i+3]:-1),  nnxt = (i+5<len ? tree[i+5]:-1),  prv = (i==0 ? -1 : tree[i-1]);
                if(l==0 && nxt==l && nnxt==l) {
                    var lz = i+5;
                    while(lz+2<len && tree[lz+2]==l) lz+=2;
                    var zc = Math.min((lz+1-i)>>>1, 138);
                    if(zc<11) set.push(17, zc-3);
                    else set.push(18, zc-11);
                    i += zc*2-2;
                }
                else if(l==prv && nxt==l && nnxt==l) {
                    var lz = i+5;
                    while(lz+2<len && tree[lz+2]==l) lz+=2;
                    var zc = Math.min((lz+1-i)>>>1, 6);
                    set.push(16, zc-3);
                    i += zc*2-2;
                }
                else set.push(l, 0);
            }
            return len>>>1;
        }
        UZIP.F._hufTree   = function(hst, tree, MAXL) {
            var list=[], hl = hst.length, tl=tree.length, i=0;
            for(i=0; i<tl; i+=2) {  tree[i]=0;  tree[i+1]=0;  }
            for(i=0; i<hl; i++) if(hst[i]!=0) list.push({lit:i, f:hst[i]});
            var end = list.length, l2=list.slice(0);
            if(end==0) return 0;  // empty histogram (usually for dist)
            if(end==1) {  var lit=list[0].lit, l2=lit==0?1:0;  tree[(lit<<1)+1]=1;  tree[(l2<<1)+1]=1;  return 1;  }
            list.sort(function(a,b){return a.f-b.f;});
            var a=list[0], b=list[1], i0=0, i1=1, i2=2;  list[0]={lit:-1,f:a.f+b.f,l:a,r:b,d:0};
            while(i1!=end-1) {
                if(i0!=i1 && (i2==end || list[i0].f<list[i2].f)) {  a=list[i0++];  }  else {  a=list[i2++];  }
                if(i0!=i1 && (i2==end || list[i0].f<list[i2].f)) {  b=list[i0++];  }  else {  b=list[i2++];  }
                list[i1++]={lit:-1,f:a.f+b.f, l:a,r:b};
            }
            var maxl = UZIP.F.setDepth(list[i1-1], 0);
            if(maxl>MAXL) {  UZIP.F.restrictDepth(l2, MAXL, maxl);  maxl = MAXL;  }
            for(i=0; i<end; i++) tree[(l2[i].lit<<1)+1]=l2[i].d;
            return maxl;
        }

        UZIP.F.setDepth  = function(t, d) {
            if(t.lit!=-1) {  t.d=d;  return d;  }
            return Math.max( UZIP.F.setDepth(t.l, d+1),  UZIP.F.setDepth(t.r, d+1) );
        }

        UZIP.F.restrictDepth = function(dps, MD, maxl) {
            var i=0, bCost=1<<(maxl-MD), dbt=0;
            dps.sort(function(a,b){return b.d==a.d ? a.f-b.f : b.d-a.d;});
            
            for(i=0; i<dps.length; i++) if(dps[i].d>MD) {  var od=dps[i].d;  dps[i].d=MD;  dbt+=bCost-(1<<(maxl-od));  }  else break;
            dbt = dbt>>>(maxl-MD);
            while(dbt>0) {  var od=dps[i].d;  if(od<MD) {  dps[i].d++;  dbt-=(1<<(MD-od-1));  }  else  i++;  }
            for(; i>=0; i--) if(dps[i].d==MD && dbt<0) {  dps[i].d--;  dbt++;  }  if(dbt!=0) console.log(\"debt left\");
        }

        UZIP.F._goodIndex = function(v, arr) {
            var i=0;  if(arr[i|16]<=v) i|=16;  if(arr[i|8]<=v) i|=8;  if(arr[i|4]<=v) i|=4;  if(arr[i|2]<=v) i|=2;  if(arr[i|1]<=v) i|=1;  return i;
        }
        UZIP.F._writeLit = function(ch, ltree, out, pos) {
            UZIP.F._putsF(out, pos, ltree[ch<<1]);
            return pos+ltree[(ch<<1)+1];
        }








        UZIP.F.inflate = function(data, buf) {
            var u8=Uint8Array;
            if(data[0]==3 && data[1]==0) return (buf ? buf : new u8(0));
            var F=UZIP.F, bitsF = F._bitsF, bitsE = F._bitsE, decodeTiny = F._decodeTiny, makeCodes = F.makeCodes, codes2map=F.codes2map, get17 = F._get17;
            var U = F.U;
            
            var noBuf = (buf==null);
            if(noBuf) buf = new u8((data.length>>>2)<<3);
            
            var BFINAL=0, BTYPE=0, HLIT=0, HDIST=0, HCLEN=0, ML=0, MD=0;
            var off = 0, pos = 0;
            var lmap, dmap;
            
            while(BFINAL==0) {
                BFINAL = bitsF(data, pos  , 1);
                BTYPE  = bitsF(data, pos+1, 2);  pos+=3;
                //console.log(BFINAL, BTYPE);
                
                if(BTYPE==0) {
                    if((pos&7)!=0) pos+=8-(pos&7);
                    var p8 = (pos>>>3)+4, len = data[p8-4]|(data[p8-3]<<8);  //console.log(len);//bitsF(data, pos, 16),
                    if(noBuf) buf=UZIP.F._check(buf, off+len);
                    buf.set(new u8(data.buffer, data.byteOffset+p8, len), off);
                    //for(var i=0; i<len; i++) buf[off+i] = data[p8+i];
                    //for(var i=0; i<len; i++) if(buf[off+i] != data[p8+i]) throw \"e\";
                    pos = ((p8+len)<<3);  off+=len;  continue;
                }
                if(noBuf) buf=UZIP.F._check(buf, off+(1<<17));  // really not enough in many cases (but PNG and ZIP provide buffer in advance)
                if(BTYPE==1) {  lmap = U.flmap;  dmap = U.fdmap;  ML = (1<<9)-1;  MD = (1<<5)-1;   }
                if(BTYPE==2) {
                    HLIT  = bitsE(data, pos   , 5)+257;
                    HDIST = bitsE(data, pos+ 5, 5)+  1;
                    HCLEN = bitsE(data, pos+10, 4)+  4;  pos+=14;
                    
                    var ppos = pos;
                    for(var i=0; i<38; i+=2) {  U.itree[i]=0;  U.itree[i+1]=0;  }
                    var tl = 1;
                    for(var i=0; i<HCLEN; i++) {  var l=bitsE(data, pos+i*3, 3);  U.itree[(U.ordr[i]<<1)+1] = l;  if(l>tl)tl=l;  }     pos+=3*HCLEN;  //console.log(itree);
                    makeCodes(U.itree, tl);
                    codes2map(U.itree, tl, U.imap);
                    
                    lmap = U.lmap;  dmap = U.dmap;
                    
                    pos = decodeTiny(U.imap, (1<<tl)-1, HLIT+HDIST, data, pos, U.ttree);
                    var mx0 = F._copyOut(U.ttree,    0, HLIT , U.ltree);  ML = (1<<mx0)-1;
                    var mx1 = F._copyOut(U.ttree, HLIT, HDIST, U.dtree);  MD = (1<<mx1)-1;
                    
                    //var ml = decodeTiny(U.imap, (1<<tl)-1, HLIT , data, pos, U.ltree); ML = (1<<(ml>>>24))-1;  pos+=(ml&0xffffff);
                    makeCodes(U.ltree, mx0);
                    codes2map(U.ltree, mx0, lmap);
                    
                    //var md = decodeTiny(U.imap, (1<<tl)-1, HDIST, data, pos, U.dtree); MD = (1<<(md>>>24))-1;  pos+=(md&0xffffff);
                    makeCodes(U.dtree, mx1);
                    codes2map(U.dtree, mx1, dmap);
                }
                //var ooff=off, opos=pos;
                while(true) {
                    var code = lmap[get17(data, pos) & ML];  pos += code&15;
                    var lit = code>>>4;  //U.lhst[lit]++;
                    if((lit>>>8)==0) {  buf[off++] = lit;  }
                    else if(lit==256) {  break;  }
                    else {
                        var end = off+lit-254;
                        if(lit>264) { var ebs = U.ldef[lit-257];  end = off + (ebs>>>3) + bitsE(data, pos, ebs&7);  pos += ebs&7;  }
                        //UZIP.F.dst[end-off]++;
                        
                        var dcode = dmap[get17(data, pos) & MD];  pos += dcode&15;
                        var dlit = dcode>>>4;
                        var dbs = U.ddef[dlit], dst = (dbs>>>4) + bitsF(data, pos, dbs&15);  pos += dbs&15;
                        
                        //var o0 = off-dst, stp = Math.min(end-off, dst);
                        //if(stp>20) while(off<end) {  buf.copyWithin(off, o0, o0+stp);  off+=stp;  }  else
                        //if(end-dst<=off) buf.copyWithin(off, off-dst, end-dst);  else
                        //if(dst==1) buf.fill(buf[off-1], off, end);  else
                        if(noBuf) buf=UZIP.F._check(buf, off+(1<<17));
                        while(off<end) {  buf[off]=buf[off++-dst];    buf[off]=buf[off++-dst];  buf[off]=buf[off++-dst];  buf[off]=buf[off++-dst];  }
                        off=end;
                        //while(off!=end) {  buf[off]=buf[off++-dst];  }
                    }
                }
                //console.log(off-ooff, (pos-opos)>>>3);
            }
            //console.log(UZIP.F.dst);
            //console.log(tlen, dlen, off-tlen+tcnt);
            return buf.length==off ? buf : buf.slice(0,off);
        }
        UZIP.F._check=function(buf, len) {
            var bl=buf.length;  if(len<=bl) return buf;
            var nbuf = new Uint8Array(Math.max(bl<<1,len));  nbuf.set(buf,0);
            //for(var i=0; i<bl; i+=4) {  nbuf[i]=buf[i];  nbuf[i+1]=buf[i+1];  nbuf[i+2]=buf[i+2];  nbuf[i+3]=buf[i+3];  }
            return nbuf;
        }

        UZIP.F._decodeTiny = function(lmap, LL, len, data, pos, tree) {
            var bitsE = UZIP.F._bitsE, get17 = UZIP.F._get17;
            var i = 0;
            while(i<len) {
                var code = lmap[get17(data, pos)&LL];  pos+=code&15;
                var lit = code>>>4;
                if(lit<=15) {  tree[i]=lit;  i++;  }
                else {
                    var ll = 0, n = 0;
                    if(lit==16) {
                        n = (3  + bitsE(data, pos, 2));  pos += 2;  ll = tree[i-1];
                    }
                    else if(lit==17) {
                        n = (3  + bitsE(data, pos, 3));  pos += 3;
                    }
                    else if(lit==18) {
                        n = (11 + bitsE(data, pos, 7));  pos += 7;
                    }
                    var ni = i+n;
                    while(i<ni) {  tree[i]=ll;  i++; }
                }
            }
            return pos;
        }
        UZIP.F._copyOut = function(src, off, len, tree) {
            var mx=0, i=0, tl=tree.length>>>1;
            while(i<len) {  var v=src[i+off];  tree[(i<<1)]=0;  tree[(i<<1)+1]=v;  if(v>mx)mx=v;  i++;  }
            while(i<tl ) {  tree[(i<<1)]=0;  tree[(i<<1)+1]=0;  i++;  }
            return mx;
        }

        UZIP.F.makeCodes = function(tree, MAX_BITS) {  // code, length
            var U = UZIP.F.U;
            var max_code = tree.length;
            var code, bits, n, i, len;
            
            var bl_count = U.bl_count;  for(var i=0; i<=MAX_BITS; i++) bl_count[i]=0;
            for(i=1; i<max_code; i+=2) bl_count[tree[i]]++;
            
            var next_code = U.next_code;    // smallest code for each length
            
            code = 0;
            bl_count[0] = 0;
            for (bits = 1; bits <= MAX_BITS; bits++) {
                code = (code + bl_count[bits-1]) << 1;
                next_code[bits] = code;
            }
            
            for (n = 0; n < max_code; n+=2) {
                len = tree[n+1];
                if (len != 0) {
                    tree[n] = next_code[len];
                    next_code[len]++;
                }
            }
        }
        UZIP.F.codes2map = function(tree, MAX_BITS, map) {
            var max_code = tree.length;
            var U=UZIP.F.U, r15 = U.rev15;
            for(var i=0; i<max_code; i+=2) if(tree[i+1]!=0)  {
                var lit = i>>1;
                var cl = tree[i+1], val = (lit<<4)|cl; // :  (0x8000 | (U.of0[lit-257]<<7) | (U.exb[lit-257]<<4) | cl);
                var rest = (MAX_BITS-cl), i0 = tree[i]<<rest, i1 = i0 + (1<<rest);
                //tree[i]=r15[i0]>>>(15-MAX_BITS);
                while(i0!=i1) {
                    var p0 = r15[i0]>>>(15-MAX_BITS);
                    map[p0]=val;  i0++;
                }
            }
        }
        UZIP.F.revCodes = function(tree, MAX_BITS) {
            var r15 = UZIP.F.U.rev15, imb = 15-MAX_BITS;
            for(var i=0; i<tree.length; i+=2) {  var i0 = (tree[i]<<(MAX_BITS-tree[i+1]));  tree[i] = r15[i0]>>>imb;  }
        }

        // used only in deflate
        UZIP.F._putsE= function(dt, pos, val   ) {  val = val<<(pos&7);  var o=(pos>>>3);  dt[o]|=val;  dt[o+1]|=(val>>>8);                        }
        UZIP.F._putsF= function(dt, pos, val   ) {  val = val<<(pos&7);  var o=(pos>>>3);  dt[o]|=val;  dt[o+1]|=(val>>>8);  dt[o+2]|=(val>>>16);  }

        UZIP.F._bitsE= function(dt, pos, length) {  return ((dt[pos>>>3] | (dt[(pos>>>3)+1]<<8)                        )>>>(pos&7))&((1<<length)-1);  }
        UZIP.F._bitsF= function(dt, pos, length) {  return ((dt[pos>>>3] | (dt[(pos>>>3)+1]<<8) | (dt[(pos>>>3)+2]<<16))>>>(pos&7))&((1<<length)-1);  }
        /*
        UZIP.F._get9 = function(dt, pos) {
            return ((dt[pos>>>3] | (dt[(pos>>>3)+1]<<8))>>>(pos&7))&511;
        } */
        UZIP.F._get17= function(dt, pos) {    // return at least 17 meaningful bytes
            return (dt[pos>>>3] | (dt[(pos>>>3)+1]<<8) | (dt[(pos>>>3)+2]<<16) )>>>(pos&7);
        }
        UZIP.F._get25= function(dt, pos) {    // return at least 17 meaningful bytes
            return (dt[pos>>>3] | (dt[(pos>>>3)+1]<<8) | (dt[(pos>>>3)+2]<<16) | (dt[(pos>>>3)+3]<<24) )>>>(pos&7);
        }
        UZIP.F.U = function(){
            var u16=Uint16Array, u32=Uint32Array;
            return {
                next_code : new u16(16),
                bl_count  : new u16(16),
                ordr : [ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 ],
                of0  : [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258,999,999,999],
                exb  : [0,0,0,0,0,0,0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4,  4,  5,  5,  5,  5,  0,  0,  0,  0],
                ldef : new u16(32),
                df0  : [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577, 65535, 65535],
                dxb  : [0,0,0,0,1,1,2, 2, 3, 3, 4, 4, 5, 5,  6,  6,  7,  7,  8,  8,   9,   9,  10,  10,  11,  11,  12,   12,   13,   13,     0,     0],
                ddef : new u32(32),
                flmap: new u16(  512),  fltree: [],
                fdmap: new u16(   32),  fdtree: [],
                lmap : new u16(32768),  ltree : [],  ttree:[],
                dmap : new u16(32768),  dtree : [],
                imap : new u16(  512),  itree : [],
                //rev9 : new u16(  512)
                rev15: new u16(1<<15),
                lhst : new u32(286), dhst : new u32( 30), ihst : new u32(19),
                lits : new u32(15000),
                strt : new u16(1<<16),
                prev : new u16(1<<15)
            };
        } ();

        (function(){
            var U = UZIP.F.U;
            var len = 1<<15;
            for(var i=0; i<len; i++) {
                var x = i;
                x = (((x & 0xaaaaaaaa) >>> 1) | ((x & 0x55555555) << 1));
                x = (((x & 0xcccccccc) >>> 2) | ((x & 0x33333333) << 2));
                x = (((x & 0xf0f0f0f0) >>> 4) | ((x & 0x0f0f0f0f) << 4));
                x = (((x & 0xff00ff00) >>> 8) | ((x & 0x00ff00ff) << 8));
                U.rev15[i] = (((x >>> 16) | (x << 16)))>>>17;
            }
            
            function pushV(tgt, n, sv) {  while(n--!=0) tgt.push(0,sv);  }
            
            for(var i=0; i<32; i++) {  U.ldef[i]=(U.of0[i]<<3)|U.exb[i];  U.ddef[i]=(U.df0[i]<<4)|U.dxb[i];  }
            
            pushV(U.fltree, 144, 8);  pushV(U.fltree, 255-143, 9);  pushV(U.fltree, 279-255, 7);  pushV(U.fltree,287-279,8);
            /*
            var i = 0;
            for(; i<=143; i++) U.fltree.push(0,8);
            for(; i<=255; i++) U.fltree.push(0,9);
            for(; i<=279; i++) U.fltree.push(0,7);
            for(; i<=287; i++) U.fltree.push(0,8);
            */
            UZIP.F.makeCodes(U.fltree, 9);
            UZIP.F.codes2map(U.fltree, 9, U.flmap);
            UZIP.F.revCodes (U.fltree, 9)
            
            pushV(U.fdtree,32,5);
            //for(i=0;i<32; i++) U.fdtree.push(0,5);
            UZIP.F.makeCodes(U.fdtree, 5);
            UZIP.F.codes2map(U.fdtree, 5, U.fdmap);
            UZIP.F.revCodes (U.fdtree, 5)
            
            pushV(U.itree,19,0);  pushV(U.ltree,286,0);  pushV(U.dtree,30,0);  pushV(U.ttree,320,0);
            /*
            for(var i=0; i< 19; i++) U.itree.push(0,0);
            for(var i=0; i<286; i++) U.ltree.push(0,0);
            for(var i=0; i< 30; i++) U.dtree.push(0,0);
            for(var i=0; i<320; i++) U.ttree.push(0,0);
            */
        })()
        </script>

        <!-- UPNG.js -->
        <script type=\"text/javascript\">
        var UPNG = (function() {
          
          var _bin = {
            nextZero   : function(data,p)  {  while(data[p]!=0) p++;  return p;  },
            readUshort : function(buff,p)  {  return (buff[p]<< 8) | buff[p+1];  },
            writeUshort: function(buff,p,n){  buff[p] = (n>>8)&255;  buff[p+1] = n&255;  },
            readUint   : function(buff,p)  {  return (buff[p]*(256*256*256)) + ((buff[p+1]<<16) | (buff[p+2]<< 8) | buff[p+3]);  },
            writeUint  : function(buff,p,n){  buff[p]=(n>>24)&255;  buff[p+1]=(n>>16)&255;  buff[p+2]=(n>>8)&255;  buff[p+3]=n&255;  },
            readASCII  : function(buff,p,l){  var s = \"\";  for(var i=0; i<l; i++) s += String.fromCharCode(buff[p+i]);  return s;    },
            writeASCII : function(data,p,s){  for(var i=0; i<s.length; i++) data[p+i] = s.charCodeAt(i);  },
            readBytes  : function(buff,p,l){  var arr = [];   for(var i=0; i<l; i++) arr.push(buff[p+i]);   return arr;  },
            pad : function(n) { return n.length < 2 ? \"0\" + n : n; },
            readUTF8 : function(buff, p, l) {
              var s = \"\", ns;
              for(var i=0; i<l; i++) s += \"%\" + _bin.pad(buff[p+i].toString(16));
              try {  ns = decodeURIComponent(s); }
              catch(e) {  return _bin.readASCII(buff, p, l);  }
              return  ns;
            }
          }

          function toRGBA8(out)
          {
            var w = out.width, h = out.height;
            if(out.tabs.acTL==null) return [decodeImage(out.data, w, h, out).buffer];
            
            var frms = [];
            if(out.frames[0].data==null) out.frames[0].data = out.data;
            
            var len = w*h*4, img = new Uint8Array(len), empty = new Uint8Array(len), prev=new Uint8Array(len);
            for(var i=0; i<out.frames.length; i++)
            {
              var frm = out.frames[i];
              var fx=frm.rect.x, fy=frm.rect.y, fw = frm.rect.width, fh = frm.rect.height;
              var fdata = decodeImage(frm.data, fw,fh, out);
              
              if(i!=0) for(var j=0; j<len; j++) prev[j]=img[j];
              
              if     (frm.blend==0) _copyTile(fdata, fw, fh, img, w, h, fx, fy, 0);
              else if(frm.blend==1) _copyTile(fdata, fw, fh, img, w, h, fx, fy, 1);
              
              frms.push(img.buffer.slice(0));
              
              if     (frm.dispose==0) {}
              else if(frm.dispose==1) _copyTile(empty, fw, fh, img, w, h, fx, fy, 0);
              else if(frm.dispose==2) for(var j=0; j<len; j++) img[j]=prev[j];
            }
            return frms;
          }
          function decodeImage(data, w, h, out)
          {
            var area = w*h, bpp = _getBPP(out);
            var bpl = Math.ceil(w*bpp/8); // bytes per line

            var bf = new Uint8Array(area*4), bf32 = new Uint32Array(bf.buffer);
            var ctype = out.ctype, depth = out.depth;
            var rs = _bin.readUshort;
            
            //console.log(ctype, depth);
            var time = Date.now();

            if     (ctype==6) { // RGB + alpha
              var qarea = area<<2;
              if(depth== 8) for(var i=0; i<qarea;i+=4) {  bf[i] = data[i];  bf[i+1] = data[i+1];  bf[i+2] = data[i+2];  bf[i+3] = data[i+3]; }
              if(depth==16) for(var i=0; i<qarea;i++ ) {  bf[i] = data[i<<1];  }
            }
            else if(ctype==2) { // RGB
              var ts=out.tabs[\"tRNS\"];
              if(ts==null) {
                if(depth== 8) for(var i=0; i<area; i++) {  var ti=i*3;  bf32[i] = (255<<24)|(data[ti+2]<<16)|(data[ti+1]<<8)|data[ti];  }
                if(depth==16) for(var i=0; i<area; i++) {  var ti=i*6;  bf32[i] = (255<<24)|(data[ti+4]<<16)|(data[ti+2]<<8)|data[ti];  }
              }
              else {  var tr=ts[0], tg=ts[1], tb=ts[2];
                if(depth== 8) for(var i=0; i<area; i++) {  var qi=i<<2, ti=i*3;  bf32[i] = (255<<24)|(data[ti+2]<<16)|(data[ti+1]<<8)|data[ti];
                  if(data[ti]   ==tr && data[ti+1]   ==tg && data[ti+2]   ==tb) bf[qi+3] = 0;  }
                if(depth==16) for(var i=0; i<area; i++) {  var qi=i<<2, ti=i*6;  bf32[i] = (255<<24)|(data[ti+4]<<16)|(data[ti+2]<<8)|data[ti];
                  if(rs(data,ti)==tr && rs(data,ti+2)==tg && rs(data,ti+4)==tb) bf[qi+3] = 0;  }
              }
            }
            else if(ctype==3) { // palette
              var p=out.tabs[\"PLTE\"], ap=out.tabs[\"tRNS\"], tl=ap?ap.length:0;
              //console.log(p, ap);
              if(depth==1) for(var y=0; y<h; y++) {  var s0 = y*bpl, t0 = y*w;
                for(var i=0; i<w; i++) { var qi=(t0+i)<<2, j=((data[s0+(i>>3)]>>(7-((i&7)<<0)))& 1), cj=3*j;  bf[qi]=p[cj];  bf[qi+1]=p[cj+1];  bf[qi+2]=p[cj+2];  bf[qi+3]=(j<tl)?ap[j]:255;  }
              }
              if(depth==2) for(var y=0; y<h; y++) {  var s0 = y*bpl, t0 = y*w;
                for(var i=0; i<w; i++) { var qi=(t0+i)<<2, j=((data[s0+(i>>2)]>>(6-((i&3)<<1)))& 3), cj=3*j;  bf[qi]=p[cj];  bf[qi+1]=p[cj+1];  bf[qi+2]=p[cj+2];  bf[qi+3]=(j<tl)?ap[j]:255;  }
              }
              if(depth==4) for(var y=0; y<h; y++) {  var s0 = y*bpl, t0 = y*w;
                for(var i=0; i<w; i++) { var qi=(t0+i)<<2, j=((data[s0+(i>>1)]>>(4-((i&1)<<2)))&15), cj=3*j;  bf[qi]=p[cj];  bf[qi+1]=p[cj+1];  bf[qi+2]=p[cj+2];  bf[qi+3]=(j<tl)?ap[j]:255;  }
              }
              if(depth==8) for(var i=0; i<area; i++ ) {  var qi=i<<2, j=data[i]                      , cj=3*j;  bf[qi]=p[cj];  bf[qi+1]=p[cj+1];  bf[qi+2]=p[cj+2];  bf[qi+3]=(j<tl)?ap[j]:255;  }
            }
            else if(ctype==4) { // gray + alpha
              if(depth== 8)  for(var i=0; i<area; i++) {  var qi=i<<2, di=i<<1, gr=data[di];  bf[qi]=gr;  bf[qi+1]=gr;  bf[qi+2]=gr;  bf[qi+3]=data[di+1];  }
              if(depth==16)  for(var i=0; i<area; i++) {  var qi=i<<2, di=i<<2, gr=data[di];  bf[qi]=gr;  bf[qi+1]=gr;  bf[qi+2]=gr;  bf[qi+3]=data[di+2];  }
            }
            else if(ctype==0) { // gray
              var tr = out.tabs[\"tRNS\"] ? out.tabs[\"tRNS\"] : -1;
              for(var y=0; y<h; y++) {
                var off = y*bpl, to = y*w;
                if     (depth== 1) for(var x=0; x<w; x++) {  var gr=255*((data[off+(x>>>3)]>>>(7 -((x&7)   )))& 1), al=(gr==tr*255)?0:255;  bf32[to+x]=(al<<24)|(gr<<16)|(gr<<8)|gr;  }
                else if(depth== 2) for(var x=0; x<w; x++) {  var gr= 85*((data[off+(x>>>2)]>>>(6 -((x&3)<<1)))& 3), al=(gr==tr* 85)?0:255;  bf32[to+x]=(al<<24)|(gr<<16)|(gr<<8)|gr;  }
                else if(depth== 4) for(var x=0; x<w; x++) {  var gr= 17*((data[off+(x>>>1)]>>>(4 -((x&1)<<2)))&15), al=(gr==tr* 17)?0:255;  bf32[to+x]=(al<<24)|(gr<<16)|(gr<<8)|gr;  }
                else if(depth== 8) for(var x=0; x<w; x++) {  var gr=data[off+     x], al=(gr                 ==tr)?0:255;  bf32[to+x]=(al<<24)|(gr<<16)|(gr<<8)|gr;  }
                else if(depth==16) for(var x=0; x<w; x++) {  var gr=data[off+(x<<1)], al=(rs(data,off+(x<<1))==tr)?0:255;  bf32[to+x]=(al<<24)|(gr<<16)|(gr<<8)|gr;  }
              }
            }
            //console.log(Date.now()-time);
            return bf;
          }



          function decode(buff)
          {
            var data = new Uint8Array(buff), offset = 8, bin = _bin, rUs = bin.readUshort, rUi = bin.readUint;
            var out = {tabs:{}, frames:[]};
            var dd = new Uint8Array(data.length), doff = 0;  // put all IDAT data into it
            var fd, foff = 0; // frames
            
            var mgck = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
            for(var i=0; i<8; i++) if(data[i]!=mgck[i]) throw \"The input is not a PNG file!\";

            while(offset<data.length)
            {
              var len  = bin.readUint(data, offset);  offset += 4;
              var type = bin.readASCII(data, offset, 4);  offset += 4;
              //console.log(type,len);
              
              if     (type==\"IHDR\")  {  _IHDR(data, offset, out);  }
              else if(type==\"iCCP\")  {
                var off = offset;  while(data[off]!=0) off++;
                var nam = bin.readASCII(data,offset,off-offset);
                var cpr = data[off+1];
                var fil = data.slice(off+2,offset+len);
                var res = null;
                try { res = _inflate(fil); } catch(e) {  res = inflateRaw(fil);  }
                out.tabs[type] = res;
              }
              else if(type==\"CgBI\")  {  out.tabs[type] = data.slice(offset,offset+4);  }
              else if(type==\"IDAT\") {
                for(var i=0; i<len; i++) dd[doff+i] = data[offset+i];
                doff += len;
              }
              else if(type==\"acTL\")  {
                out.tabs[type] = {  num_frames:rUi(data, offset), num_plays:rUi(data, offset+4)  };
                fd = new Uint8Array(data.length);
              }
              else if(type==\"fcTL\")  {
                if(foff!=0) {  var fr = out.frames[out.frames.length-1];
                  fr.data = _decompress(out, fd.slice(0,foff), fr.rect.width, fr.rect.height);  foff=0;
                }
                var rct = {x:rUi(data, offset+12),y:rUi(data, offset+16),width:rUi(data, offset+4),height:rUi(data, offset+8)};
                var del = rUs(data, offset+22);  del = rUs(data, offset+20) / (del==0?100:del);
                var frm = {rect:rct, delay:Math.round(del*1000), dispose:data[offset+24], blend:data[offset+25]};
                //console.log(frm);
                out.frames.push(frm);
              }
              else if(type==\"fdAT\") {
                for(var i=0; i<len-4; i++) fd[foff+i] = data[offset+i+4];
                foff += len-4;
              }
              else if(type==\"pHYs\") {
                out.tabs[type] = [bin.readUint(data, offset), bin.readUint(data, offset+4), data[offset+8]];
              }
              else if(type==\"cHRM\") {
                out.tabs[type] = [];
                for(var i=0; i<8; i++) out.tabs[type].push(bin.readUint(data, offset+i*4));
              }
              else if(type==\"tEXt\" || type==\"zTXt\") {
                if(out.tabs[type]==null) out.tabs[type] = {};
                var nz = bin.nextZero(data, offset);
                var keyw = bin.readASCII(data, offset, nz-offset);
                var text, tl=offset+len-nz-1;
                if(type==\"tEXt\") text = bin.readASCII(data, nz+1, tl);
                else {
                  var bfr = _inflate(data.slice(nz+2,nz+2+tl));
                  text = bin.readUTF8(bfr,0,bfr.length);
                }
                out.tabs[type][keyw] = text;
              }
              else if(type==\"iTXt\") {
                if(out.tabs[type]==null) out.tabs[type] = {};
                var nz = 0, off = offset;
                nz = bin.nextZero(data, off);
                var keyw = bin.readASCII(data, off, nz-off);  off = nz + 1;
                var cflag = data[off], cmeth = data[off+1];  off+=2;
                nz = bin.nextZero(data, off);
                var ltag = bin.readASCII(data, off, nz-off);  off = nz + 1;
                nz = bin.nextZero(data, off);
                var tkeyw = bin.readUTF8(data, off, nz-off);  off = nz + 1;
                var text, tl=len-(off-offset);
                if(cflag==0) text  = bin.readUTF8(data, off, tl);
                else {
                  var bfr = _inflate(data.slice(off,off+tl));
                  text = bin.readUTF8(bfr,0,bfr.length);
                }
                out.tabs[type][keyw] = text;
              }
              else if(type==\"PLTE\") {
                out.tabs[type] = bin.readBytes(data, offset, len);
              }
              else if(type==\"hIST\") {
                var pl = out.tabs[\"PLTE\"].length/3;
                out.tabs[type] = [];  for(var i=0; i<pl; i++) out.tabs[type].push(rUs(data, offset+i*2));
              }
              else if(type==\"tRNS\") {
                if     (out.ctype==3) out.tabs[type] = bin.readBytes(data, offset, len);
                else if(out.ctype==0) out.tabs[type] = rUs(data, offset);
                else if(out.ctype==2) out.tabs[type] = [ rUs(data,offset),rUs(data,offset+2),rUs(data,offset+4) ];
                //else console.log(\"tRNS for unsupported color type\",out.ctype, len);
              }
              else if(type==\"gAMA\") out.tabs[type] = bin.readUint(data, offset)/100000;
              else if(type==\"sRGB\") out.tabs[type] = data[offset];
              else if(type==\"bKGD\")
              {
                if     (out.ctype==0 || out.ctype==4) out.tabs[type] = [rUs(data, offset)];
                else if(out.ctype==2 || out.ctype==6) out.tabs[type] = [rUs(data, offset), rUs(data, offset+2), rUs(data, offset+4)];
                else if(out.ctype==3) out.tabs[type] = data[offset];
              }
              else if(type==\"IEND\") {
                break;
              }
              //else {  console.log(\"unknown chunk type\", type, len);  out.tabs[type]=data.slice(offset,offset+len);  }
              offset += len;
              var crc = bin.readUint(data, offset);  offset += 4;
            }
            if(foff!=0) {  var fr = out.frames[out.frames.length-1];
              fr.data = _decompress(out, fd.slice(0,foff), fr.rect.width, fr.rect.height);
            }
            out.data = _decompress(out, dd, out.width, out.height);
            
            delete out.compress;  delete out.interlace;  delete out.filter;
            return out;
          }

          function _decompress(out, dd, w, h) {
            var time = Date.now();
            var bpp = _getBPP(out), bpl = Math.ceil(w*bpp/8), buff = new Uint8Array((bpl+1+out.interlace)*h);
            if(out.tabs[\"CgBI\"]) dd = inflateRaw(dd,buff);
            else                 dd = _inflate(dd,buff);
            //console.log(dd.length, buff.length);
            //console.log(Date.now()-time);

            var time=Date.now();
            if     (out.interlace==0) dd = _filterZero(dd, out, 0, w, h);
            else if(out.interlace==1) dd = _readInterlace(dd, out);
            //console.log(Date.now()-time);
            return dd;
          }

          function _inflate(data, buff) {  var out=inflateRaw(new Uint8Array(data.buffer, 2,data.length-6),buff);  return out;  }
          
          var inflateRaw=function(){var H={};H.H={};H.H.N=function(N,W){var R=Uint8Array,i=0,m=0,J=0,h=0,Q=0,X=0,u=0,w=0,d=0,v,C;
          if(N[0]==3&&N[1]==0)return W?W:new R(0);var V=H.H,n=V.b,A=V.e,l=V.R,M=V.n,I=V.A,e=V.Z,b=V.m,Z=W==null;
          if(Z)W=new R(N.length>>>2<<5);while(i==0){i=n(N,d,1);m=n(N,d+1,2);d+=3;if(m==0){if((d&7)!=0)d+=8-(d&7);
          var D=(d>>>3)+4,q=N[D-4]|N[D-3]<<8;if(Z)W=H.H.W(W,w+q);W.set(new R(N.buffer,N.byteOffset+D,q),w);d=D+q<<3;
          w+=q;continue}if(Z)W=H.H.W(W,w+(1<<17));if(m==1){v=b.J;C=b.h;X=(1<<9)-1;u=(1<<5)-1}if(m==2){J=A(N,d,5)+257;
          h=A(N,d+5,5)+1;Q=A(N,d+10,4)+4;d+=14;var E=d,j=1;for(var c=0;c<38;c+=2){b.Q[c]=0;b.Q[c+1]=0}for(var c=0;
          c<Q;c++){var K=A(N,d+c*3,3);b.Q[(b.X[c]<<1)+1]=K;if(K>j)j=K}d+=3*Q;M(b.Q,j);I(b.Q,j,b.u);v=b.w;C=b.d;
          d=l(b.u,(1<<j)-1,J+h,N,d,b.v);var r=V.V(b.v,0,J,b.C);X=(1<<r)-1;var S=V.V(b.v,J,h,b.D);u=(1<<S)-1;M(b.C,r);
          I(b.C,r,v);M(b.D,S);I(b.D,S,C)}while(!0){var T=v[e(N,d)&X];d+=T&15;var p=T>>>4;if(p>>>8==0){W[w++]=p}else if(p==256){break}else{var z=w+p-254;
          if(p>264){var _=b.q[p-257];z=w+(_>>>3)+A(N,d,_&7);d+=_&7}var $=C[e(N,d)&u];d+=$&15;var s=$>>>4,Y=b.c[s],a=(Y>>>4)+n(N,d,Y&15);
          d+=Y&15;while(w<z){W[w]=W[w++-a];W[w]=W[w++-a];W[w]=W[w++-a];W[w]=W[w++-a]}w=z}}}return W.length==w?W:W.slice(0,w)};
          H.H.W=function(N,W){var R=N.length;if(W<=R)return N;var V=new Uint8Array(R<<1);V.set(N,0);return V};
          H.H.R=function(N,W,R,V,n,A){var l=H.H.e,M=H.H.Z,I=0;while(I<R){var e=N[M(V,n)&W];n+=e&15;var b=e>>>4;
          if(b<=15){A[I]=b;I++}else{var Z=0,m=0;if(b==16){m=3+l(V,n,2);n+=2;Z=A[I-1]}else if(b==17){m=3+l(V,n,3);
          n+=3}else if(b==18){m=11+l(V,n,7);n+=7}var J=I+m;while(I<J){A[I]=Z;I++}}}return n};H.H.V=function(N,W,R,V){var n=0,A=0,l=V.length>>>1;
          while(A<R){var M=N[A+W];V[A<<1]=0;V[(A<<1)+1]=M;if(M>n)n=M;A++}while(A<l){V[A<<1]=0;V[(A<<1)+1]=0;A++}return n};
          H.H.n=function(N,W){var R=H.H.m,V=N.length,n,A,l,M,I,e=R.j;for(var M=0;M<=W;M++)e[M]=0;for(M=1;M<V;M+=2)e[N[M]]++;
          var b=R.K;n=0;e[0]=0;for(A=1;A<=W;A++){n=n+e[A-1]<<1;b[A]=n}for(l=0;l<V;l+=2){I=N[l+1];if(I!=0){N[l]=b[I];
          b[I]++}}};H.H.A=function(N,W,R){var V=N.length,n=H.H.m,A=n.r;for(var l=0;l<V;l+=2)if(N[l+1]!=0){var M=l>>1,I=N[l+1],e=M<<4|I,b=W-I,Z=N[l]<<b,m=Z+(1<<b);
          while(Z!=m){var J=A[Z]>>>15-W;R[J]=e;Z++}}};H.H.l=function(N,W){var R=H.H.m.r,V=15-W;for(var n=0;n<N.length;
          n+=2){var A=N[n]<<W-N[n+1];N[n]=R[A]>>>V}};H.H.M=function(N,W,R){R=R<<(W&7);var V=W>>>3;N[V]|=R;N[V+1]|=R>>>8};
          H.H.I=function(N,W,R){R=R<<(W&7);var V=W>>>3;N[V]|=R;N[V+1]|=R>>>8;N[V+2]|=R>>>16};H.H.e=function(N,W,R){return(N[W>>>3]|N[(W>>>3)+1]<<8)>>>(W&7)&(1<<R)-1};
          H.H.b=function(N,W,R){return(N[W>>>3]|N[(W>>>3)+1]<<8|N[(W>>>3)+2]<<16)>>>(W&7)&(1<<R)-1};H.H.Z=function(N,W){return(N[W>>>3]|N[(W>>>3)+1]<<8|N[(W>>>3)+2]<<16)>>>(W&7)};
          H.H.i=function(N,W){return(N[W>>>3]|N[(W>>>3)+1]<<8|N[(W>>>3)+2]<<16|N[(W>>>3)+3]<<24)>>>(W&7)};H.H.m=function(){var N=Uint16Array,W=Uint32Array;
          return{K:new N(16),j:new N(16),X:[16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15],S:[3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258,999,999,999],T:[0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0,0,0,0],q:new N(32),p:[1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577,65535,65535],z:[0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,0,0],c:new W(32),J:new N(512),_:[],h:new N(32),$:[],w:new N(32768),C:[],v:[],d:new N(32768),D:[],u:new N(512),Q:[],r:new N(1<<15),s:new W(286),Y:new W(30),a:new W(19),t:new W(15e3),k:new N(1<<16),g:new N(1<<15)}}();
          (function(){var N=H.H.m,W=1<<15;for(var R=0;R<W;R++){var V=R;V=(V&2863311530)>>>1|(V&1431655765)<<1;
          V=(V&3435973836)>>>2|(V&858993459)<<2;V=(V&4042322160)>>>4|(V&252645135)<<4;V=(V&4278255360)>>>8|(V&16711935)<<8;
          N.r[R]=(V>>>16|V<<16)>>>17}function n(A,l,M){while(l--!=0)A.push(0,M)}for(var R=0;R<32;R++){N.q[R]=N.S[R]<<3|N.T[R];
          N.c[R]=N.p[R]<<4|N.z[R]}n(N._,144,8);n(N._,255-143,9);n(N._,279-255,7);n(N._,287-279,8);H.H.n(N._,9);
          H.H.A(N._,9,N.J);H.H.l(N._,9);n(N.$,32,5);H.H.n(N.$,5);H.H.A(N.$,5,N.h);H.H.l(N.$,5);n(N.Q,19,0);n(N.C,286,0);
          n(N.D,30,0);n(N.v,320,0)}());return H.H.N}()


          function _readInterlace(data, out)
          {
            var w = out.width, h = out.height;
            var bpp = _getBPP(out), cbpp = bpp>>3, bpl = Math.ceil(w*bpp/8);
            var img = new Uint8Array( h * bpl );
            var di = 0;

            var starting_row  = [ 0, 0, 4, 0, 2, 0, 1 ];
            var starting_col  = [ 0, 4, 0, 2, 0, 1, 0 ];
            var row_increment = [ 8, 8, 8, 4, 4, 2, 2 ];
            var col_increment = [ 8, 8, 4, 4, 2, 2, 1 ];

            var pass=0;
            while(pass<7)
            {
              var ri = row_increment[pass], ci = col_increment[pass];
              var sw = 0, sh = 0;
              var cr = starting_row[pass];  while(cr<h) {  cr+=ri;  sh++;  }
              var cc = starting_col[pass];  while(cc<w) {  cc+=ci;  sw++;  }
              var bpll = Math.ceil(sw*bpp/8);
              _filterZero(data, out, di, sw, sh);

              var y=0, row = starting_row[pass];
              while(row<h)
              {
                var col = starting_col[pass];
                var cdi = (di+y*bpll)<<3;

                while(col<w)
                {
                  if(bpp==1) {
                    var val = data[cdi>>3];  val = (val>>(7-(cdi&7)))&1;
                    img[row*bpl + (col>>3)] |= (val << (7-((col&7)<<0)));
                  }
                  if(bpp==2) {
                    var val = data[cdi>>3];  val = (val>>(6-(cdi&7)))&3;
                    img[row*bpl + (col>>2)] |= (val << (6-((col&3)<<1)));
                  }
                  if(bpp==4) {
                    var val = data[cdi>>3];  val = (val>>(4-(cdi&7)))&15;
                    img[row*bpl + (col>>1)] |= (val << (4-((col&1)<<2)));
                  }
                  if(bpp>=8) {
                    var ii = row*bpl+col*cbpp;
                    for(var j=0; j<cbpp; j++) img[ii+j] = data[(cdi>>3)+j];
                  }
                  cdi+=bpp;  col+=ci;
                }
                y++;  row += ri;
              }
              if(sw*sh!=0) di += sh * (1 + bpll);
              pass = pass + 1;
            }
            return img;
          }

          function _getBPP(out) {
            var noc = [1,null,3,1,2,null,4][out.ctype];
            return noc * out.depth;
          }

          function _filterZero(data, out, off, w, h)
          {
            var bpp = _getBPP(out), bpl = Math.ceil(w*bpp/8);
            bpp = Math.ceil(bpp/8);
            
            var i,di, type=data[off], x=0;
            
            if(type>1) data[off]=[0,0,1][type-2];
            if(type==3) for(x=bpp; x<bpl; x++) data[x+1] = (data[x+1] + (data[x+1-bpp]>>>1) )&255;

            for(var y=0; y<h; y++)  {
              i = off+y*bpl; di = i+y+1;
              type = data[di-1]; x=0;

              if     (type==0)   for(; x<bpl; x++) data[i+x] = data[di+x];
              else if(type==1) { for(; x<bpp; x++) data[i+x] = data[di+x];
                         for(; x<bpl; x++) data[i+x] = (data[di+x] + data[i+x-bpp]);  }
              else if(type==2) { for(; x<bpl; x++) data[i+x] = (data[di+x] + data[i+x-bpl]);  }
              else if(type==3) { for(; x<bpp; x++) data[i+x] = (data[di+x] + ( data[i+x-bpl]>>>1));
                         for(; x<bpl; x++) data[i+x] = (data[di+x] + ((data[i+x-bpl]+data[i+x-bpp])>>>1) );  }
              else             { for(; x<bpp; x++) data[i+x] = (data[di+x] + _paeth(0, data[i+x-bpl], 0));
                         for(; x<bpl; x++) data[i+x] = (data[di+x] + _paeth(data[i+x-bpp], data[i+x-bpl], data[i+x-bpp-bpl]) );  }
            }
            return data;
          }

          function _paeth(a,b,c)
          {
            var p = a+b-c, pa = (p-a), pb = (p-b), pc = (p-c);
            if (pa*pa <= pb*pb && pa*pa <= pc*pc)  return a;
            else if (pb*pb <= pc*pc)  return b;
            return c;
          }

          function _IHDR(data, offset, out)
          {
            out.width  = _bin.readUint(data, offset);  offset += 4;
            out.height = _bin.readUint(data, offset);  offset += 4;
            out.depth     = data[offset];  offset++;
            out.ctype     = data[offset];  offset++;
            out.compress  = data[offset];  offset++;
            out.filter    = data[offset];  offset++;
            out.interlace = data[offset];  offset++;
          }

          function _copyTile(sb, sw, sh, tb, tw, th, xoff, yoff, mode)
          {
            var w = Math.min(sw,tw), h = Math.min(sh,th);
            var si=0, ti=0;
            for(var y=0; y<h; y++)
              for(var x=0; x<w; x++)
              {
                if(xoff>=0 && yoff>=0) {  si = (y*sw+x)<<2;  ti = (( yoff+y)*tw+xoff+x)<<2;  }
                else                   {  si = ((-yoff+y)*sw-xoff+x)<<2;  ti = (y*tw+x)<<2;  }
                
                if     (mode==0) {  tb[ti] = sb[si];  tb[ti+1] = sb[si+1];  tb[ti+2] = sb[si+2];  tb[ti+3] = sb[si+3];  }
                else if(mode==1) {
                  var fa = sb[si+3]*(1/255), fr=sb[si]*fa, fg=sb[si+1]*fa, fb=sb[si+2]*fa;
                  var ba = tb[ti+3]*(1/255), br=tb[ti]*ba, bg=tb[ti+1]*ba, bb=tb[ti+2]*ba;
                  
                  var ifa=1-fa, oa = fa+ba*ifa, ioa = (oa==0?0:1/oa);
                  tb[ti+3] = 255*oa;
                  tb[ti+0] = (fr+br*ifa)*ioa;
                  tb[ti+1] = (fg+bg*ifa)*ioa;
                  tb[ti+2] = (fb+bb*ifa)*ioa;
                }
                else if(mode==2){ // copy only differences, otherwise zero
                  var fa = sb[si+3], fr=sb[si], fg=sb[si+1], fb=sb[si+2];
                  var ba = tb[ti+3], br=tb[ti], bg=tb[ti+1], bb=tb[ti+2];
                  if(fa==ba && fr==br && fg==bg && fb==bb) {  tb[ti]=0;  tb[ti+1]=0;  tb[ti+2]=0;  tb[ti+3]=0;  }
                  else {  tb[ti]=fr;  tb[ti+1]=fg;  tb[ti+2]=fb;  tb[ti+3]=fa;  }
                }
                else if(mode==3){ // check if can be blended
                  var fa = sb[si+3], fr=sb[si], fg=sb[si+1], fb=sb[si+2];
                  var ba = tb[ti+3], br=tb[ti], bg=tb[ti+1], bb=tb[ti+2];
                  if(fa==ba && fr==br && fg==bg && fb==bb) continue;
                  //if(fa!=255 && ba!=0) return false;
                  if(fa<220 && ba>20) return false;
                }
              }
            return true;
          }
          
          return {
            decode:decode,
            toRGBA8:toRGBA8,
            _paeth:_paeth,
            _copyTile:_copyTile,
            _bin:_bin
          };

        })();









        (function() {
          var _copyTile = UPNG._copyTile, _bin=UPNG._bin, paeth = UPNG._paeth;
          var crcLib = {
            table : ( function() {
               var tab = new Uint32Array(256);
               for (var n=0; n<256; n++) {
                var c = n;
                for (var k=0; k<8; k++) {
                  if (c & 1)  c = 0xedb88320 ^ (c >>> 1);
                  else        c = c >>> 1;
                }
                tab[n] = c;  }
              return tab;  })(),
            update : function(c, buf, off, len) {
              for (var i=0; i<len; i++)  c = crcLib.table[(c ^ buf[off+i]) & 0xff] ^ (c >>> 8);
              return c;
            },
            crc : function(b,o,l)  {  return crcLib.update(0xffffffff,b,o,l) ^ 0xffffffff;  }
          }
          
          
          function addErr(er, tg, ti, f) {
            tg[ti]+=(er[0]*f)>>4;  tg[ti+1]+=(er[1]*f)>>4;  tg[ti+2]+=(er[2]*f)>>4;  tg[ti+3]+=(er[3]*f)>>4;
          }
          function N(x) {  return Math.max(0, Math.min(255, x));  }
          function D(a,b) {  var dr=a[0]-b[0], dg=a[1]-b[1], db=a[2]-b[2], da=a[3]-b[3];  return (dr*dr + dg*dg + db*db + da*da);  }
            
          // MTD: 0: None, 1: floyd-steinberg, 2: Bayer
          function dither(sb, w, h, plte, tb, oind, MTD) {
            if(MTD==null) MTD=1;
            
            var pc=plte.length, nplt = [], rads=[];
            for(var i=0; i<pc; i++) {
              var c = plte[i];
              nplt.push([((c>>>0)&255), ((c>>>8)&255), ((c>>>16)&255), ((c>>>24)&255)]);
            }
            for(var i=0; i<pc; i++) {
              var ne=0xffffffff, ni=0;
              for(var j=0; j<pc; j++) {  var ce=D(nplt[i],nplt[j]);  if(j!=i && ce<ne) {  ne=ce;  ni=j;  }  }
              var hd = Math.sqrt(ne)/2;
              rads[i] = ~~(hd*hd);
            }
              
            var tb32 = new Uint32Array(tb.buffer);
            var err = new Int16Array(w*h*4);
            
            /*
            var S=2, M = [
              0,2,
                3,1];  //*/
            //*
            var S=4, M = [
               0, 8, 2,10,
                12, 4,14, 6,
               3,11, 1, 9,
              15, 7,13, 5 ];  //*/
            for(var i=0; i<M.length; i++) M[i] = 255*(-0.5 + (M[i]+0.5)/(S*S));
            
            for(var y=0; y<h; y++) {
              for(var x=0; x<w; x++) {
                var i = (y*w+x)*4;
                
                var cc;
                if(MTD!=2) cc = [N(sb[i]+err[i]), N(sb[i+1]+err[i+1]), N(sb[i+2]+err[i+2]), N(sb[i+3]+err[i+3])];
                else {
                  var ce = M[(y&(S-1))*S+(x&(S-1))];
                  cc = [N(sb[i]+ce), N(sb[i+1]+ce), N(sb[i+2]+ce), N(sb[i+3]+ce)];
                }
                
                var ni=0, nd = 0xffffff;
                for(var j=0; j<pc; j++) {
                  var cd = D(cc,nplt[j]);
                  if(cd<nd) {  nd=cd;  ni=j;  }
                }
                
                var nc = nplt[ni];
                var er = [cc[0]-nc[0], cc[1]-nc[1], cc[2]-nc[2], cc[3]-nc[3]];
                
                if(MTD==1) {
                  //addErr(er, err, i+4, 16);
                  if(x!=w-1) addErr(er, err, i+4    , 7);
                  if(y!=h-1) {
                    if(x!=  0) addErr(er, err, i+4*w-4, 3);
                           addErr(er, err, i+4*w  , 5);
                    if(x!=w-1) addErr(er, err, i+4*w+4, 1);
                  }//*/
                }
                oind[i>>2] = ni;  tb32[i>>2] = plte[ni];
              }
            }
          }

          
          function encode(bufs, w, h, ps, dels, tabs, forbidPlte)
          {
            if(ps==null) ps=0;
            if(forbidPlte==null) forbidPlte = false;

            var nimg = compress(bufs, w, h, ps, [false, false, false, 0, forbidPlte,false]);
            compressPNG(nimg, -1);
            
            return _main(nimg, w, h, dels, tabs);
          }

          function encodeLL(bufs, w, h, cc, ac, depth, dels, tabs) {
            var nimg = {  ctype: 0 + (cc==1 ? 0 : 2) + (ac==0 ? 0 : 4),      depth: depth,  frames: []  };
            
            var time = Date.now();
            var bipp = (cc+ac)*depth, bipl = bipp * w;
            for(var i=0; i<bufs.length; i++)
              nimg.frames.push({  rect:{x:0,y:0,width:w,height:h},  img:new Uint8Array(bufs[i]), blend:0, dispose:1, bpp:Math.ceil(bipp/8), bpl:Math.ceil(bipl/8)  });
            
            compressPNG(nimg, 0, true);
            
            var out = _main(nimg, w, h, dels, tabs);
            return out;
          }

          function _main(nimg, w, h, dels, tabs) {
            if(tabs==null) tabs={};
            var crc = crcLib.crc, wUi = _bin.writeUint, wUs = _bin.writeUshort, wAs = _bin.writeASCII;
            var offset = 8, anim = nimg.frames.length>1, pltAlpha = false;
            
            var cicc;
            
            var leng = 8 + (16+5+4) /*+ (9+4)*/ + (anim ? 20 : 0);
            if(tabs[\"sRGB\"]!=null) leng += 8+1+4;
            if(tabs[\"pHYs\"]!=null) leng += 8+9+4;
            if(tabs[\"iCCP\"]!=null) {  cicc = window.UZIP.deflate(tabs[\"iCCP\"]);  leng += 8 + 11 + 2 + cicc.length + 4;  }
            if(nimg.ctype==3) {
              var dl = nimg.plte.length;
              for(var i=0; i<dl; i++) if((nimg.plte[i]>>>24)!=255) pltAlpha = true;
              leng += (8 + dl*3 + 4) + (pltAlpha ? (8 + dl*1 + 4) : 0);
            }
            for(var j=0; j<nimg.frames.length; j++)
            {
              var fr = nimg.frames[j];
              if(anim) leng += 38;
              leng += fr.cimg.length + 12;
              if(j!=0) leng+=4;
            }
            leng += 12;
            
            var data = new Uint8Array(leng);
            var wr=[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
            for(var i=0; i<8; i++) data[i]=wr[i];
            
            wUi(data,offset, 13);     offset+=4;
            wAs(data,offset,\"IHDR\");  offset+=4;
            wUi(data,offset,w);  offset+=4;
            wUi(data,offset,h);  offset+=4;
            data[offset] = nimg.depth;  offset++;  // depth
            data[offset] = nimg.ctype;  offset++;  // ctype
            data[offset] = 0;  offset++;  // compress
            data[offset] = 0;  offset++;  // filter
            data[offset] = 0;  offset++;  // interlace
            wUi(data,offset,crc(data,offset-17,17));  offset+=4; // crc

            // 13 bytes to say, that it is sRGB
            if(tabs[\"sRGB\"]!=null) {
              wUi(data,offset, 1);      offset+=4;
              wAs(data,offset,\"sRGB\");  offset+=4;
              data[offset] = tabs[\"sRGB\"];  offset++;
              wUi(data,offset,crc(data,offset-5,5));  offset+=4; // crc
            }
            if(tabs[\"iCCP\"]!=null) {
              var sl = 11+2+cicc.length;
              wUi(data,offset, sl);  offset+=4;
              wAs(data,offset,\"iCCP\");  offset+=4;
              wAs(data,offset,\"ICC profile\");  offset+=11;  offset+=2;
              data.set(cicc, offset);  offset+=cicc.length;
              wUi(data,offset,crc(data,offset-(sl+4),sl+4));  offset+=4; // crc
            }
            if(tabs[\"pHYs\"]!=null) {
              wUi(data,offset, 9);      offset+=4;
              wAs(data,offset,\"pHYs\");  offset+=4;
              wUi(data,offset, tabs[\"pHYs\"][0]);      offset+=4;
              wUi(data,offset, tabs[\"pHYs\"][1]);      offset+=4;
              data[offset]=tabs[\"pHYs\"][2];     offset++;
              wUi(data,offset,crc(data,offset-13,13));  offset+=4; // crc
            }

            if(anim) {
              wUi(data,offset, 8);      offset+=4;
              wAs(data,offset,\"acTL\");  offset+=4;
              wUi(data,offset, nimg.frames.length);     offset+=4;
              wUi(data,offset, tabs[\"loop\"]!=null?tabs[\"loop\"]:0);      offset+=4;
              wUi(data,offset,crc(data,offset-12,12));  offset+=4; // crc
            }

            if(nimg.ctype==3) {
              var dl = nimg.plte.length;
              wUi(data,offset, dl*3);  offset+=4;
              wAs(data,offset,\"PLTE\");  offset+=4;
              for(var i=0; i<dl; i++){
                var ti=i*3, c=nimg.plte[i], r=(c)&255, g=(c>>>8)&255, b=(c>>>16)&255;
                data[offset+ti+0]=r;  data[offset+ti+1]=g;  data[offset+ti+2]=b;
              }
              offset+=dl*3;
              wUi(data,offset,crc(data,offset-dl*3-4,dl*3+4));  offset+=4; // crc

              if(pltAlpha) {
                wUi(data,offset, dl);  offset+=4;
                wAs(data,offset,\"tRNS\");  offset+=4;
                for(var i=0; i<dl; i++)  data[offset+i]=(nimg.plte[i]>>>24)&255;
                offset+=dl;
                wUi(data,offset,crc(data,offset-dl-4,dl+4));  offset+=4; // crc
              }
            }
            
            var fi = 0;
            for(var j=0; j<nimg.frames.length; j++)
            {
              var fr = nimg.frames[j];
              if(anim) {
                wUi(data, offset, 26);     offset+=4;
                wAs(data, offset,\"fcTL\");  offset+=4;
                wUi(data, offset, fi++);   offset+=4;
                wUi(data, offset, fr.rect.width );   offset+=4;
                wUi(data, offset, fr.rect.height);   offset+=4;
                wUi(data, offset, fr.rect.x);   offset+=4;
                wUi(data, offset, fr.rect.y);   offset+=4;
                wUs(data, offset, dels[j]);   offset+=2;
                wUs(data, offset,  1000);   offset+=2;
                data[offset] = fr.dispose;  offset++; // dispose
                data[offset] = fr.blend  ;  offset++; // blend
                wUi(data,offset,crc(data,offset-30,30));  offset+=4; // crc
              }
                  
              var imgd = fr.cimg, dl = imgd.length;
              wUi(data,offset, dl+(j==0?0:4));     offset+=4;
              var ioff = offset;
              wAs(data,offset,(j==0)?\"IDAT\":\"fdAT\");  offset+=4;
              if(j!=0) {  wUi(data, offset, fi++);  offset+=4;  }
              data.set(imgd,offset);
              offset += dl;
              wUi(data,offset,crc(data,ioff,offset-ioff));  offset+=4; // crc
            }

            wUi(data,offset, 0);     offset+=4;
            wAs(data,offset,\"IEND\");  offset+=4;
            wUi(data,offset,crc(data,offset-4,4));  offset+=4; // crc

            return data.buffer;
          }

          function compressPNG(out, filter, levelZero) {
            for(var i=0; i<out.frames.length; i++) {
              var frm = out.frames[i], nw=frm.rect.width, nh=frm.rect.height;
              var fdata = new Uint8Array(nh*frm.bpl+nh);
              frm.cimg = _filterZero(frm.img,nh,frm.bpp,frm.bpl,fdata, filter, levelZero);
            }
          }



          function compress(bufs, w, h, ps, prms) // prms:  onlyBlend, minBits, forbidPlte
          {
            //var time = Date.now();
            var onlyBlend = prms[0], evenCrd = prms[1], forbidPrev = prms[2], minBits = prms[3], forbidPlte = prms[4], dith=prms[5];
            
            var ctype = 6, depth = 8, alphaAnd=255
            
            for(var j=0; j<bufs.length; j++)  {  // when not quantized, other frames can contain colors, that are not in an initial frame
              var img = new Uint8Array(bufs[j]), ilen = img.length;
              for(var i=0; i<ilen; i+=4) alphaAnd &= img[i+3];
            }
            var gotAlpha = (alphaAnd!=255);
            
            //console.log(\"alpha check\", Date.now()-time);  time = Date.now();
            
            //var brute = gotAlpha && forGIF;   // brute : frames can only be copied, not \"blended\"
            var frms = framize(bufs, w, h, onlyBlend, evenCrd, forbidPrev);
            //console.log(\"framize\", Date.now()-time);  time = Date.now();
            
            var cmap={}, plte=[], inds=[];
            
            if(ps!=0) {
              var nbufs = [];  for(var i=0; i<frms.length; i++) nbufs.push(frms[i].img.buffer);
              
              var abuf = concatRGBA(nbufs), qres = quantize(abuf, ps);
              
              for(var i=0; i<qres.plte.length; i++) plte.push(qres.plte[i].est.rgba);
              
              var cof = 0;
              for(var i=0; i<frms.length; i++) {
                var frm=frms[i], bln=frm.img.length, ind = new Uint8Array(qres.inds.buffer, cof>>2, bln>>2);  inds.push(ind);
                var bb = new Uint8Array(qres.abuf,cof,bln);
                
                //console.log(frm.img, frm.width, frm.height);
                //var time = Date.now();
                if(dith) dither(frm.img, frm.rect.width, frm.rect.height, plte, bb, ind);
                //console.log(Date.now()-time);
                frm.img.set(bb);  cof+=bln;
              }
              
              //console.log(\"quantize\", Date.now()-time);  time = Date.now();
            }
            else {
              // what if ps==0, but there are <=256 colors?  we still need to detect, if the palette could be used
              for(var j=0; j<frms.length; j++)  {  // when not quantized, other frames can contain colors, that are not in an initial frame
                var frm = frms[j], img32 = new Uint32Array(frm.img.buffer), nw=frm.rect.width, ilen = img32.length;
                var ind = new Uint8Array(ilen);  inds.push(ind);
                for(var i=0; i<ilen; i++) {
                  var c = img32[i];
                  if     (i!=0 && c==img32[i- 1]) ind[i]=ind[i-1];
                  else if(i>nw && c==img32[i-nw]) ind[i]=ind[i-nw];
                  else {
                    var cmc = cmap[c];
                    if(cmc==null) {  cmap[c]=cmc=plte.length;  plte.push(c);  if(plte.length>=300) break;  }
                    ind[i]=cmc;
                  }
                }
              }
              //console.log(\"make palette\", Date.now()-time);  time = Date.now();
            }
            
            var cc=plte.length; //console.log(\"colors:\",cc);
            if(cc<=256 && forbidPlte==false) {
              if(cc<= 2) depth=1;  else if(cc<= 4) depth=2;  else if(cc<=16) depth=4;  else depth=8;
              depth =  Math.max(depth, minBits);
            }
            
            for(var j=0; j<frms.length; j++)
            {
              var frm = frms[j], nx=frm.rect.x, ny=frm.rect.y, nw=frm.rect.width, nh=frm.rect.height;
              var cimg = frm.img, cimg32 = new Uint32Array(cimg.buffer);
              var bpl = 4*nw, bpp=4;
              if(cc<=256 && forbidPlte==false) {
                bpl = Math.ceil(depth*nw/8);
                var nimg = new Uint8Array(bpl*nh);
                var inj = inds[j];
                for(var y=0; y<nh; y++) {  var i=y*bpl, ii=y*nw;
                  if     (depth==8) for(var x=0; x<nw; x++) nimg[i+(x)   ]   =  (inj[ii+x]             );
                  else if(depth==4) for(var x=0; x<nw; x++) nimg[i+(x>>1)]  |=  (inj[ii+x]<<(4-(x&1)*4));
                  else if(depth==2) for(var x=0; x<nw; x++) nimg[i+(x>>2)]  |=  (inj[ii+x]<<(6-(x&3)*2));
                  else if(depth==1) for(var x=0; x<nw; x++) nimg[i+(x>>3)]  |=  (inj[ii+x]<<(7-(x&7)*1));
                }
                cimg=nimg;  ctype=3;  bpp=1;
              }
              else if(gotAlpha==false && frms.length==1) {  // some next \"reduced\" frames may contain alpha for blending
                var nimg = new Uint8Array(nw*nh*3), area=nw*nh;
                for(var i=0; i<area; i++) { var ti=i*3, qi=i*4;  nimg[ti]=cimg[qi];  nimg[ti+1]=cimg[qi+1];  nimg[ti+2]=cimg[qi+2];  }
                cimg=nimg;  ctype=2;  bpp=3;  bpl=3*nw;
              }
              frm.img=cimg;  frm.bpl=bpl;  frm.bpp=bpp;
            }
            //console.log(\"colors => palette indices\", Date.now()-time);  time = Date.now();
            
            return {ctype:ctype, depth:depth, plte:plte, frames:frms  };
          }
          function framize(bufs,w,h,alwaysBlend,evenCrd,forbidPrev) {
            /*  DISPOSE
              - 0 : no change
              - 1 : clear to transparent
              - 2 : retstore to content before rendering (previous frame disposed)
              BLEND
              - 0 : replace
              - 1 : blend
            */
            var frms = [];
            for(var j=0; j<bufs.length; j++) {
              var cimg = new Uint8Array(bufs[j]), cimg32 = new Uint32Array(cimg.buffer);
              var nimg;
              
              var nx=0, ny=0, nw=w, nh=h, blend=alwaysBlend?1:0;
              if(j!=0) {
                var tlim = (forbidPrev || alwaysBlend || j==1 || frms[j-2].dispose!=0)?1:2, tstp = 0, tarea = 1e9;
                for(var it=0; it<tlim; it++)
                {
                  var pimg = new Uint8Array(bufs[j-1-it]), p32 = new Uint32Array(bufs[j-1-it]);
                  var mix=w,miy=h,max=-1,may=-1;
                  for(var y=0; y<h; y++) for(var x=0; x<w; x++) {
                    var i = y*w+x;
                    if(cimg32[i]!=p32[i]) {
                      if(x<mix) mix=x;  if(x>max) max=x;
                      if(y<miy) miy=y;  if(y>may) may=y;
                    }
                  }
                  if(max==-1) mix=miy=max=may=0;
                  if(evenCrd) {  if((mix&1)==1)mix--;  if((miy&1)==1)miy--;  }
                  var sarea = (max-mix+1)*(may-miy+1);
                  if(sarea<tarea) {
                    tarea = sarea;  tstp = it;
                    nx = mix; ny = miy; nw = max-mix+1; nh = may-miy+1;
                  }
                }
                
                // alwaysBlend: pokud zjistím, že blendit nelze, nastavím předchozímu snímku dispose=1. Zajistím, aby obsahoval můj obdélník.
                var pimg = new Uint8Array(bufs[j-1-tstp]);
                if(tstp==1) frms[j-1].dispose = 2;
                
                nimg = new Uint8Array(nw*nh*4);
                _copyTile(pimg,w,h, nimg,nw,nh, -nx,-ny, 0);
                
                blend =  _copyTile(cimg,w,h, nimg,nw,nh, -nx,-ny, 3) ? 1 : 0;
                if(blend==1) _prepareDiff(cimg,w,h,nimg,{x:nx,y:ny,width:nw,height:nh});
                else         _copyTile(cimg,w,h, nimg,nw,nh, -nx,-ny, 0);
              }
              else nimg = cimg.slice(0);  // img may be rewritten further ... don't rewrite input
              
              frms.push({rect:{x:nx,y:ny,width:nw,height:nh}, img:nimg, blend:blend, dispose:0});
            }
            
            
            if(alwaysBlend) for(var j=0; j<frms.length; j++) {
              var frm = frms[j];  if(frm.blend==1) continue;
              var r0 = frm.rect, r1 = frms[j-1].rect
              var miX = Math.min(r0.x, r1.x), miY = Math.min(r0.y, r1.y);
              var maX = Math.max(r0.x+r0.width, r1.x+r1.width), maY = Math.max(r0.y+r0.height, r1.y+r1.height);
              var r = {x:miX, y:miY, width:maX-miX, height:maY-miY};
              
              frms[j-1].dispose = 1;
              if(j-1!=0)
              _updateFrame(bufs, w,h,frms, j-1,r, evenCrd);
              _updateFrame(bufs, w,h,frms, j  ,r, evenCrd);
            }
            var area = 0;
            if(bufs.length!=1) for(var i=0; i<frms.length; i++) {
              var frm = frms[i];
              area += frm.rect.width*frm.rect.height;
              //if(i==0 || frm.blend!=1) continue;
              //var ob = new Uint8Array(
              //console.log(frm.blend, frm.dispose, frm.rect);
            }
            //if(area!=0) console.log(area);
            return frms;
          }
          function _updateFrame(bufs, w,h, frms, i, r, evenCrd) {
            var U8 = Uint8Array, U32 = Uint32Array;
            var pimg = new U8(bufs[i-1]), pimg32 = new U32(bufs[i-1]), nimg = i+1<bufs.length ? new U8(bufs[i+1]):null;
            var cimg = new U8(bufs[i]), cimg32 = new U32(cimg.buffer);
            
            var mix=w,miy=h,max=-1,may=-1;
            for(var y=0; y<r.height; y++) for(var x=0; x<r.width; x++) {
              var cx = r.x+x, cy = r.y+y;
              var j = cy*w+cx, cc = cimg32[j];
              // no need to draw transparency, or to dispose it. Or, if writing the same color and the next one does not need transparency.
              if(cc==0 || (frms[i-1].dispose==0 && pimg32[j]==cc && (nimg==null || nimg[j*4+3]!=0))/**/) {}
              else {
                if(cx<mix) mix=cx;  if(cx>max) max=cx;
                if(cy<miy) miy=cy;  if(cy>may) may=cy;
              }
            }
            if(max==-1) mix=miy=max=may=0;
            if(evenCrd) {  if((mix&1)==1)mix--;  if((miy&1)==1)miy--;  }
            r = {x:mix, y:miy, width:max-mix+1, height:may-miy+1};
            
            var fr = frms[i];  fr.rect = r;  fr.blend = 1;  fr.img = new Uint8Array(r.width*r.height*4);
            if(frms[i-1].dispose==0) {
              _copyTile(pimg,w,h, fr.img,r.width,r.height, -r.x,-r.y, 0);
              _prepareDiff(cimg,w,h,fr.img,r);
            }
            else
              _copyTile(cimg,w,h, fr.img,r.width,r.height, -r.x,-r.y, 0);
          }
          function _prepareDiff(cimg, w,h, nimg, rec) {
            _copyTile(cimg,w,h, nimg,rec.width,rec.height, -rec.x,-rec.y, 2);
          }

          function _filterZero(img,h,bpp,bpl,data, filter, levelZero)
          {
            var fls = [], ftry=[0,1,2,3,4];
            if     (filter!=-1)             ftry=[filter];
            else if(h*bpl>500000 || bpp==1) ftry=[0];
            var opts;  if(levelZero) opts={level:0};
            
            
            var CMPR = window.UZIP;
            
            var time = Date.now();
            for(var i=0; i<ftry.length; i++) {
              for(var y=0; y<h; y++) _filterLine(data, img, y, bpl, bpp, ftry[i]);
              //var nimg = new Uint8Array(data.length);
              //var sz = UZIP.F.deflate(data, nimg);  fls.push(nimg.slice(0,sz));
              //var dfl = pako[\"deflate\"](data), dl=dfl.length-4;
              //var crc = (dfl[dl+3]<<24)|(dfl[dl+2]<<16)|(dfl[dl+1]<<8)|(dfl[dl+0]<<0);
              //console.log(crc, UZIP.adler(data,2,data.length-6));
              fls.push(CMPR[\"deflate\"](data,opts));
            }
            
            var ti, tsize=1e9;
            for(var i=0; i<fls.length; i++) if(fls[i].length<tsize) {  ti=i;  tsize=fls[i].length;  }
            return fls[ti];
          }
          function _filterLine(data, img, y, bpl, bpp, type)
          {
            var i = y*bpl, di = i+y;
            data[di]=type;  di++;

            if(type==0) {
              if(bpl<500) for(var x=0; x<bpl; x++) data[di+x] = img[i+x];
              else data.set(new Uint8Array(img.buffer,i,bpl),di);
            }
            else if(type==1) {
              for(var x=  0; x<bpp; x++) data[di+x] =  img[i+x];
              for(var x=bpp; x<bpl; x++) data[di+x] = (img[i+x]-img[i+x-bpp]+256)&255;
            }
            else if(y==0) {
              for(var x=  0; x<bpp; x++) data[di+x] = img[i+x];

              if(type==2) for(var x=bpp; x<bpl; x++) data[di+x] = img[i+x];
              if(type==3) for(var x=bpp; x<bpl; x++) data[di+x] = (img[i+x] - (img[i+x-bpp]>>1) +256)&255;
              if(type==4) for(var x=bpp; x<bpl; x++) data[di+x] = (img[i+x] - paeth(img[i+x-bpp], 0, 0) +256)&255;
            }
            else {
              if(type==2) { for(var x=  0; x<bpl; x++) data[di+x] = (img[i+x]+256 - img[i+x-bpl])&255;  }
              if(type==3) { for(var x=  0; x<bpp; x++) data[di+x] = (img[i+x]+256 - (img[i+x-bpl]>>1))&255;
                      for(var x=bpp; x<bpl; x++) data[di+x] = (img[i+x]+256 - ((img[i+x-bpl]+img[i+x-bpp])>>1))&255;  }
              if(type==4) { for(var x=  0; x<bpp; x++) data[di+x] = (img[i+x]+256 - paeth(0, img[i+x-bpl], 0))&255;
                      for(var x=bpp; x<bpl; x++) data[di+x] = (img[i+x]+256 - paeth(img[i+x-bpp], img[i+x-bpl], img[i+x-bpp-bpl]))&255;  }
            }
          }


          function quantize(abuf, ps)
          {
            var sb = new Uint8Array(abuf), tb = sb.slice(0), tb32 = new Uint32Array(tb.buffer);
            
            var KD = getKDtree(tb, ps);
            var root = KD[0], leafs = KD[1];
            
            var len=sb.length;
              
            var inds = new Uint8Array(len>>2), nd;
            if(sb.length<20e6)  // precise, but slow :(
              for(var i=0; i<len; i+=4) {
                var r=sb[i]*(1/255), g=sb[i+1]*(1/255), b=sb[i+2]*(1/255), a=sb[i+3]*(1/255);
                
                nd = getNearest(root, r, g, b, a);
                inds[i>>2] = nd.ind;  tb32[i>>2] = nd.est.rgba;
              }
            else
              for(var i=0; i<len; i+=4) {
                var r=sb[i]*(1/255), g=sb[i+1]*(1/255), b=sb[i+2]*(1/255), a=sb[i+3]*(1/255);
                
                nd = root;  while(nd.left) nd = (planeDst(nd.est,r,g,b,a)<=0) ? nd.left : nd.right;
                inds[i>>2] = nd.ind;  tb32[i>>2] = nd.est.rgba;
              }
            return {  abuf:tb.buffer, inds:inds, plte:leafs  };
          }

          function getKDtree(nimg, ps, err) {
            if(err==null) err = 0.0001;
            var nimg32 = new Uint32Array(nimg.buffer);
            
            var root = {i0:0, i1:nimg.length, bst:null, est:null, tdst:0, left:null, right:null };  // basic statistic, extra statistic
            root.bst = stats(  nimg,root.i0, root.i1  );  root.est = estats( root.bst );
            var leafs = [root];
            
            while(leafs.length<ps)
            {
              var maxL = 0, mi=0;
              for(var i=0; i<leafs.length; i++) if(leafs[i].est.L > maxL) {  maxL=leafs[i].est.L;  mi=i;  }
              if(maxL<err) break;
              var node = leafs[mi];
              
              var s0 = splitPixels(nimg,nimg32, node.i0, node.i1, node.est.e, node.est.eMq255);
              var s0wrong = (node.i0>=s0 || node.i1<=s0);
              //console.log(maxL, leafs.length, mi);
              if(s0wrong) {  node.est.L=0;  continue;  }
              
              
              var ln = {i0:node.i0, i1:s0, bst:null, est:null, tdst:0, left:null, right:null };  ln.bst = stats( nimg, ln.i0, ln.i1 );
              ln.est = estats( ln.bst );
              var rn = {i0:s0, i1:node.i1, bst:null, est:null, tdst:0, left:null, right:null };  rn.bst = {R:[], m:[], N:node.bst.N-ln.bst.N};
              for(var i=0; i<16; i++) rn.bst.R[i] = node.bst.R[i]-ln.bst.R[i];
              for(var i=0; i< 4; i++) rn.bst.m[i] = node.bst.m[i]-ln.bst.m[i];
              rn.est = estats( rn.bst );
              
              node.left = ln;  node.right = rn;
              leafs[mi]=ln;  leafs.push(rn);
            }
            leafs.sort(function(a,b) {  return b.bst.N-a.bst.N;  });
            for(var i=0; i<leafs.length; i++) leafs[i].ind=i;
            return [root, leafs];
          }

          function getNearest(nd, r,g,b,a)
          {
            if(nd.left==null) {  nd.tdst = dist(nd.est.q,r,g,b,a);  return nd;  }
            var pd = planeDst(nd.est,r,g,b,a);
            
            var node0 = nd.left, node1 = nd.right;
            if(pd>0) {  node0=nd.right;  node1=nd.left;  }
            
            var ln = getNearest(node0, r,g,b,a);
            if(ln.tdst<=pd*pd) return ln;
            var rn = getNearest(node1, r,g,b,a);
            return rn.tdst<ln.tdst ? rn : ln;
          }
          function planeDst(est, r,g,b,a) {  var e = est.e;  return e[0]*r + e[1]*g + e[2]*b + e[3]*a - est.eMq;  }
          function dist    (q,   r,g,b,a) {  var d0=r-q[0], d1=g-q[1], d2=b-q[2], d3=a-q[3];  return d0*d0+d1*d1+d2*d2+d3*d3;  }

          function splitPixels(nimg, nimg32, i0, i1, e, eMq)
          {
            i1-=4;
            var shfs = 0;
            while(i0<i1)
            {
              while(vecDot(nimg, i0, e)<=eMq) i0+=4;
              while(vecDot(nimg, i1, e)> eMq) i1-=4;
              if(i0>=i1) break;
              
              var t = nimg32[i0>>2];  nimg32[i0>>2] = nimg32[i1>>2];  nimg32[i1>>2]=t;
              
              i0+=4;  i1-=4;
            }
            while(vecDot(nimg, i0, e)>eMq) i0-=4;
            return i0+4;
          }
          function vecDot(nimg, i, e)
          {
            return nimg[i]*e[0] + nimg[i+1]*e[1] + nimg[i+2]*e[2] + nimg[i+3]*e[3];
          }
          function stats(nimg, i0, i1){
            var R = [0,0,0,0,  0,0,0,0,  0,0,0,0,  0,0,0,0];
            var m = [0,0,0,0];
            var N = (i1-i0)>>2;
            for(var i=i0; i<i1; i+=4)
            {
              var r = nimg[i]*(1/255), g = nimg[i+1]*(1/255), b = nimg[i+2]*(1/255), a = nimg[i+3]*(1/255);
              //var r = nimg[i], g = nimg[i+1], b = nimg[i+2], a = nimg[i+3];
              m[0]+=r;  m[1]+=g;  m[2]+=b;  m[3]+=a;
              
              R[ 0] += r*r;  R[ 1] += r*g;  R[ 2] += r*b;  R[ 3] += r*a;
                       R[ 5] += g*g;  R[ 6] += g*b;  R[ 7] += g*a;
                              R[10] += b*b;  R[11] += b*a;
                                     R[15] += a*a;
            }
            R[4]=R[1];  R[8]=R[2];  R[9]=R[6];  R[12]=R[3];  R[13]=R[7];  R[14]=R[11];
            
            return {R:R, m:m, N:N};
          }
          function estats(stats){
            var R = stats.R, m = stats.m, N = stats.N;
            
            // when all samples are equal, but N is large (millions), the Rj can be non-zero ( 0.0003.... - precission error)
            var m0 = m[0], m1 = m[1], m2 = m[2], m3 = m[3], iN = (N==0 ? 0 : 1/N);
            var Rj = [
              R[ 0] - m0*m0*iN,  R[ 1] - m0*m1*iN,  R[ 2] - m0*m2*iN,  R[ 3] - m0*m3*iN,
              R[ 4] - m1*m0*iN,  R[ 5] - m1*m1*iN,  R[ 6] - m1*m2*iN,  R[ 7] - m1*m3*iN,
              R[ 8] - m2*m0*iN,  R[ 9] - m2*m1*iN,  R[10] - m2*m2*iN,  R[11] - m2*m3*iN,
              R[12] - m3*m0*iN,  R[13] - m3*m1*iN,  R[14] - m3*m2*iN,  R[15] - m3*m3*iN
            ];
            
            var A = Rj, M = M4;
            var b = [Math.random(),Math.random(),Math.random(),Math.random()], mi = 0, tmi = 0;
            
            if(N!=0)
            for(var i=0; i<16; i++) {
              b = M.multVec(A, b);  tmi = Math.sqrt(M.dot(b,b));  b = M.sml(1/tmi,  b);
              if(i!=0 && Math.abs(tmi-mi)<1e-9) break;  mi = tmi;
            }
            //b = [0,0,1,0];  mi=N;
            var q = [m0*iN, m1*iN, m2*iN, m3*iN];
            var eMq255 = M.dot(M.sml(255,q),b);
            
            return {  Cov:Rj, q:q, e:b, L:mi,  eMq255:eMq255, eMq : M.dot(b,q),
                  rgba: (((Math.round(255*q[3])<<24) | (Math.round(255*q[2])<<16) |  (Math.round(255*q[1])<<8) | (Math.round(255*q[0])<<0))>>>0)  };
          }
          var M4 = {
            multVec : function(m,v) {
                return [
                  m[ 0]*v[0] + m[ 1]*v[1] + m[ 2]*v[2] + m[ 3]*v[3],
                  m[ 4]*v[0] + m[ 5]*v[1] + m[ 6]*v[2] + m[ 7]*v[3],
                  m[ 8]*v[0] + m[ 9]*v[1] + m[10]*v[2] + m[11]*v[3],
                  m[12]*v[0] + m[13]*v[1] + m[14]*v[2] + m[15]*v[3]
                ];
            },
            dot : function(x,y) {  return  x[0]*y[0]+x[1]*y[1]+x[2]*y[2]+x[3]*y[3];  },
            sml : function(a,y) {  return [a*y[0],a*y[1],a*y[2],a*y[3]];  }
          }

          function concatRGBA(bufs) {
            var tlen = 0;
            for(var i=0; i<bufs.length; i++) tlen += bufs[i].byteLength;
            var nimg = new Uint8Array(tlen), noff=0;
            for(var i=0; i<bufs.length; i++) {
              var img = new Uint8Array(bufs[i]), il = img.length;
              for(var j=0; j<il; j+=4) {
                var r=img[j], g=img[j+1], b=img[j+2], a = img[j+3];
                if(a==0) r=g=b=0;
                nimg[noff+j]=r;  nimg[noff+j+1]=g;  nimg[noff+j+2]=b;  nimg[noff+j+3]=a;  }
              noff += il;
            }
            return nimg.buffer;
          }
          
          UPNG.encode = encode;
          UPNG.encodeLL = encodeLL;
          UPNG.encode.compress = compress;
          UPNG.encode.dither = dither;
          
          UPNG.quantize = quantize;
          UPNG.quantize.getKDtree=getKDtree;
          UPNG.quantize.getNearest=getNearest;
        })();

        </script>

        <script type=\"text/javascript\">
        
          var pngs = [];
          var curr = -1;
          var cnum = 256; // quality
          var cnv, ctx;
          var main, list, totl, fopn
          var viw = 0, vih = 0;
          var ioff = {x:0, y:0}, mouse=null;
          
          function save(buff, path)
          {
            if(pngs.length==0) return;
            var data = new Uint8Array(buff);
            var a = document.createElement( \"a\" );
            var blob = new Blob([data]);
            var url = window.URL.createObjectURL( blob );
            a.href = url;  a.download = path;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
          }

          function newimageToBase64String(buff)
          {
            if(pngs.length==0) return;
            var data = new Uint8Array(buff);
            var blob = new Blob([data]);
            
            var reader = new FileReader();
            reader.readAsDataURL(blob);
            reader.onloadend = function() {
              var base64dataString = reader.result;
              // console.log(base64dataString);
              document.getElementById('base64-result-textarea').value = base64dataString;
            }
          }

          function inputBase64Image()
          {
            var base64String = document.getElementById('base64-textarea').value;
            var dataurl = `data:text/plain;base64,${base64String}`

            var arr = dataurl.split(','),
                mime = arr[0].match(/:(.*?);/)[1],
                bstr = atob(arr[1]),
                n = bstr.length,
                u8arr = new Uint8Array(n);
                
            while(n--){
                u8arr[n] = bstr.charCodeAt(n);
            }

            var f = new File([u8arr], 'base64File.png', {type:mime});
            var r = new FileReader();
            r._file = f;
            r.onload = dropLoaded;
            r.readAsArrayBuffer(f);
          }

          function saveAll()
          {
            var obj = {};
            for(var i=0; i<pngs.length; i++) obj[pngs[i].name] = new Uint8Array(pngs[i].ndata);
            save(UZIP.encode(obj).buffer, \"images.zip\");
          }
            
          function loadURL(path, resp)
          {
            var request = new XMLHttpRequest();
            request._fname = path;
            request.open(\"GET\", path, true);
            request.responseType = \"arraybuffer\";
            request.onload = urlLoaded;
            request.send();
          }
          function urlLoaded(e) {  addPNG(e.target.response, e.target._fname);  }
          
          function addPNG(buff, name)
          {
            var w, h, rgbas, ofmt=\"png\", delays;
          
            var mgc=[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], ubuff=new Uint8Array(buff);
            if(ubuff[0]==0xff && ubuff[1]==0xd8 && ubuff[2]==0xff) { // JPG
              var j = new PDFJS[\"JpegImage\"]();  j[\"parse\"](ubuff);
              w = j[\"width\"];  h = j[\"height\"]; var area = w*h;
              var data = j[\"getData\"]({\"width\":w,\"height\":h,\"forceRGB\":true,\"isSourcePDF\":false});
                
              var nbuf = new Uint8Array(area*4);
              for(var i=0; i<area; i++) {
                var qi = i<<2, ti = qi-i;
                nbuf[qi  ]=data[ti+0];
                nbuf[qi+1]=data[ti+1];
                nbuf[qi+2]=data[ti+2];
                nbuf[qi+3]=255;
              }
              rgbas = [nbuf.buffer];  ofmt=\"jpg\"
            }
            else {
              for(var i=0; i<8; i++) if(mgc[i]!=ubuff[i]) return;
              var img  = UPNG.decode(buff);  rgbas = UPNG.toRGBA8(img);  w=img.width;  h=img.height;
              delays = img.frames.map(function(rgba) {
                return new Uint8Array(rgba);
              });
            }
            var orgbas = rgbas.map(function(rgba) {
              return new Uint8Array(rgba);
            });
            var npng = {name:name, width:w, height:h, odata:buff, orgbas: orgbas, dels: delays, ndata:null, nrgba:null, ofmt:ofmt };
            var nc = pngs.length;  pngs.push(npng);  recompute(nc);  setCurr(nc);
          }
          function setCurr(nc) {  curr=nc;  ioff={x:0,y:0};  update();  }
          
          function recompute(i) {
            var p = pngs[i];
            var bufs = p.orgbas.map(function(orgba) {
              return orgba.buffer;
            });
            p.ndata = UPNG.encode(bufs, p.width, p.height, cnum, p.dels);
            if(p.ofmt==\"png\" && p.ndata.byteLength > p.odata.byteLength) p.ndata = p.odata;
            var img  = UPNG.decode(p.ndata);
            p.nrgba = new Uint8Array(UPNG.toRGBA8(img)[0]);

            newimageToBase64String(p.ndata);
          }
          
          function update()
          {
            if(curr!=-1) {
              //list.innerHTML = \"\";
              holder.innerHTML = \"\";
              totl.innerHTML = \"\";
            }
            var tos = 0, tns = 0;
            for(var i=0; i<=pngs.length; i++)
            {
              var p = pngs[i];
              var li = document.createElement(\"p\");  li.setAttribute(\"class\", \"item\"+(i==curr?\" active\":\"\")); li._indx=i;
              
              
              //var btn = document.createElement(\"button\");   btn.innerHTML = \"X\";  if(i<pngs.length) li.appendChild(btn);
              
              var iname, os, ns, cont, pw=0, ph=0;
              if(i<pngs.length) {  iname=p.name;  os = p.odata.byteLength;  ns = p.ndata.byteLength;  tos+=os;  tns+=ns;  cont=list;  pw=p.width;  ph=p.height;
                         li.addEventListener(\"click\", itemClick, false);    }
              else              {  iname=\"Total:\";  os = tos;  ns = tns;  cont = totl;  }
              
              var cnt = \"<b class=\\"fname\\" title=\\"\"+pw+\" x \"+ph+\"\\">\"+iname+\"</b>\";
              
              cnt += toBlock(toKB(os)) + toBlock(\"➜\",2) + toBlock(\"<b>\"+toKB(ns)+\"</b>\") + toBlock((100*(ns-os)/os).toFixed(1)+\" %\", 5);
              //if(i<pngs.length) cnt += toBlock(\"<big>✖</big>\",2);
              li.innerHTML = cnt;
              var btn = document.createElement(\"button\");   btn.innerHTML = \"Save\";  if(i<pngs.length) li.appendChild(btn);
              
              if(pngs.length!=0)  cont.appendChild(li);
            }
            
            var dpr = getDPR();
            var iw = window.innerWidth-2;
            var pw = Math.floor(Math.min(iw-500, iw/2)*dpr);
            
            var ph = Math.floor(vih*dpr);
              
            cnv.width = pw;  cnv.height = ph;
            var aval = \"cursor:grab; cursor:-moz-grab; cursor:-webkit-grab; background-size:\"+(16/getDPR())+\"px;\"
            cnv.setAttribute(\"style\", aval+\"width:\"+(pw/dpr)+\"px; height:\"+(ph/dpr)+\"px;\");
            
            if(curr!=-1) {
              var p = pngs[curr], l = p.width*p.height*4;
              var imgd = ctx.createImageData(p.width, p.height);
              for(var i=0; i<l; i++) imgd.data[i] = p.nrgba[i];
              ctx.clearRect(0,0,cnv.width,cnv.height);
              var rx = (pw-p.width)/2, ry = (ph-p.height)/2;
              
              if(rx<0) ioff.x = Math.max(rx, Math.min(-rx, ioff.x*getDPR()))/getDPR();
              if(ry<0) ioff.y = Math.max(ry, Math.min(-ry, ioff.y*getDPR()))/getDPR();
              
              var cx = (rx>0) ? rx : Math.min(0, Math.max(2*rx, ioff.x*getDPR()+rx));
              var cy = (ry>0) ? ry : Math.min(0, Math.max(2*ry, ioff.y*getDPR()+ry));
              ctx.putImageData(imgd,Math.round(cx), Math.round(cy));
            }
          }
          function itemClick(e) {  var ind=e.currentTarget._indx;  setCurr(ind);  var p=pngs[ind];  if(e.target.tagName==\"BUTTON\") save(p.ndata, p.name);   }
          
          function toKB(n) {  n=n/1024;  return (n>=100 ? Math.floor(n) : n.toFixed(1))+\" kB\";  }
          function toBlock(txt, w) {  var st = w ? \" style=\\"width:\"+w+\"em;\\"\":\"\";  return \"<span\"+st+\">\"+txt+\"</span>\";  }
        
          function Go()
          {
            main = document.getElementById(\"main\");
            list = document.getElementById(\"list\");
            totl = document.getElementById(\"totl\");
            cnv = document.getElementById(\"cnv\");  ctx = cnv.getContext(\"2d\");
            cnv.addEventListener(\"mousedown\", onMD, false);
            
            
            fopn = document.createElement(\"input\");
            fopn.setAttribute(\"type\", \"file\");
            fopn.addEventListener(\"change\", onFileDrop, false);
            document.body.appendChild(fopn);
            fopn.setAttribute(\"style\", \"display:none\");
            fopn.setAttribute(\"multiple\",\"\");
            
            var dc = document.body;
            
            dc.addEventListener(\"dragover\", cancel);
            dc.addEventListener(\"dragenter\", cancel);//highlight);
            dc.addEventListener(\"dragleave\", cancel);//unhighlight);
            dc.addEventListener(\"drop\", onFileDrop);
            
            window.addEventListener(\"resize\", resize);
            resize();
            //setTimeout(function() { document.getElementById(\"bunny\").setAttribute(\"style\", \"transform: translate(0, 220px)\"); }, 1000);
          }
          function onMD(e) {  mouse={x:e.clientX-ioff.x, y:e.clientY-ioff.y};  document.addEventListener(\"mousemove\",onMM,false);  document.addEventListener(\"mouseup\",onMU,false);  }
          function onMM(e) {  ioff.x=e.clientX-mouse.x;  ioff.y=e.clientY-mouse.y;  update();  }
          function onMU(e) {  document.removeEventListener(\"mousemove\",onMM,false);  document.removeEventListener(\"mouseup\",onMU,false);  }
          
          function showOpenDialog() // show open dialog
          {
            var evt = document.createEvent('MouseEvents');
            evt[\"initMouseEvent\"](\"click\", true, true, document.defaultView, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
            fopn.dispatchEvent(evt);
          }
          
          function onFileDrop(e) {  cancel(e);
            var fls = e.dataTransfer? e.dataTransfer.files : e.target.files;
            for(var i=0; i<fls.length; i++) {
              var f = fls[i];
              var r = new FileReader();
              r._file = f;
              r.onload = dropLoaded;
              r.readAsArrayBuffer(f);
            }
          }
          function dropLoaded(e) {  addPNG(e.target.result, e.target._file.name);  unhighlight(e); }
          function highlight  (e) {cancel(e); list.style.boxShadow=\"inset 0px 0px 15px blue\"; }
          function unhighlight(e) {cancel(e); list.style.boxShadow=\"none\";}
          
          function resize(e) {
            vih = window.innerHeight-(250)-4;
            viw = Math.min(1000, window.innerWidth-2);//1000;//Math.max(800, Math.floor(window.innerWidth*0.75));
            main.setAttribute(\"style\", \"width:\"+viw+\"px; height:\"+vih+\"px;\");
            list.setAttribute(\"style\", \"height:\"+(vih-40)+\"px;\");
            update();
          }
          
          function getDPR() {  return window[\"devicePixelRatio\"] || 1;  }
          function cancel(e) { e.stopPropagation(); e.preventDefault(); }
          function moveQual(val) {
            if(val>990) cnum=0;
            else cnum = Math.max(2, Math.round(510*val/1000));
            for(var i=0; i<pngs.length; i++) recompute(i);
            update();
            return val;
          }
          
        </script>
        

      </head>


      <body onload=\"Go();\">
        <div id=\"main\">
          <div id=\"lcont\">
            <div id=\"list\">
              <div class=\"divide\">
                <p>
                  <div id=\"holder\" style=\"font-size:1.3em; padding:1em; text-align:center;\">
                    <b>Shrink</b> and <b>optimize</b> images.
                    Set the <b>ideal balance</b> between the quality and the size.
                    <br/><br/>
                    <span style=\"font-size:1.5em; display:inline-block; padding:0.6em 0.2em; margin:0 1.4em; border:5px dashed #555; border-radius:0.6em; cursor:pointer;\"
                      onclick=\"showOpenDialog()\" >
                      Drag and drop your PNG files!</span>
                    <!--<input name=\"myFile\" type=\"file\" onchange=\"onFileDrop(this)\" multiple>-->
                  </div>
                </p>
                <p>
                  <textarea rows=\"10\" id=\"base64-textarea\"></textarea>
                  <button id=\"base64-button\" onclick=\"inputBase64Image();\">Input</button>
                </p>
                <p>
                  <textarea rows=\"10\" id=\"base64-result-textarea\"></textarea>
                </p>
              </div>
            </div>

            <div id=\"totl\" class=\"active\"></div>
          </div>
          <canvas id=\"cnv\"></canvas>
        </div>
        
        <div class=\"foot\">
        <footer>
            <label>Size</label>
            <input type=\"range\" id=\"eRNG\" min=\"0\" max=\"1000\" value=\"200\" style=\"width:300px; vertical-align:middle;\" oninput=\"moveQual(this.value)\" />
            <label>Quality</label>
            <button onclick=\"saveAll();\">Save all (ZIP)</button>
        </footer>
        </div>
      </body>

    </html>

    """
}
