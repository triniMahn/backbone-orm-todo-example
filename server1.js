require("coffee-script");

var app = require("./TodoServer");
//app.listen(process.env.PORT);

app.listen(process.env.PORT || 3001, process.env.IP || "0.0.0.0", function(){
  var addr = app.address();
  console.log("Server listening at", addr.address + ":" + addr.port);
});