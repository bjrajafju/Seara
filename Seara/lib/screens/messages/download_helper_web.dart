// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void downloadFile(String url, String fileName) {
  // Usar fetch para obter os bytes e criar um blob URL
  // Isto e necessario para forcar download em vez de abrir no browser
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
