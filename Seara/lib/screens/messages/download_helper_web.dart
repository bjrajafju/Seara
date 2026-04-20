import 'dart:html' as html;
import 'dart:js' as js;

// Downloads and saves the requested file
void downloadFile(String url, String fileName) {
  js.context.callMethod('eval', [
    '''
    (function() {
      fetch("$url")
        .then(function(response) { return response.blob(); })
        .then(function(blob) {
          var blobUrl = URL.createObjectURL(blob);
          var a = document.createElement("a");
          a.href = blobUrl;
          a.download = "$fileName";
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(blobUrl);
        })
        .catch(function(err) { console.error("Download failed:", err); });
    })();
    ''',
  ]);
}
