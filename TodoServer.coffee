http = require('http')
path = require('path')

express = require('express')

app = express()
server = http.createServer(app)

app.configure ->
  #Apparently, bodyParser has security issues: http://andrewkelley.me/post/do-not-use-bodyparser-with-express-js.html
  #app.use(express.bodyParser())
  app.use(express.json())
  app.use(express.static(path.resolve(__dirname, 'client')))


Backbone = require 'backbone'
RestController = require 'backbone-rest'

AppSettings = require('./_config')

class Todo extends Backbone.Model
    urlRoot: "mongodb://#{AppSettings.DB.cnnString}/Todos"
    sync: require('backbone-mongo').sync(Todo)
    defaults:
        title: ''
        completed: false
        completedDate: 0
        created: 0
        archived: false
    

new RestController(app, {model_type: Todo, route: '/todos'})

module.exports = server
