#Note: I've created these classes globally, as I didn't want module management to clutter or complicate the example

#START Models
class window.Todo extends Backbone.Model
    
    #You can use this to test the (client-side) app logic if you're having issues with BackboneORM to start
    #localStorage: new Backbone.LocalStorage('todos-backbone-marionettejs')

    urlRoot: '/todos'
    
    #Use backbone-http to communicate with your server -- overriding the model sync method here
    sync: BackboneHTTP.sync(Todo)
    
    defaults:
        title: ''
        completed: false
        completedDate: 0
        created: 0
        archived: false
        
    initialize: =>
        @set('created', Date.now()) if @isNew()
        
    toggle: =>
        @set('completed', not @isCompleted())
        @set('completedDate', Date.now()) if @isCompleted()
        @
        
    archive: =>
        @set('archived',true)
        @
        
    isCompleted: =>
        @get('completed')


#Collections must be used differently, see: https://github.com/vidigami/backbone-mongo/issues/6

class window.TodoList extends Backbone.Collection
    
    #localStorage: new Backbone.LocalStorage('todos-backbone-marionettejs')
    
    #***Order of definition of url, model, and sync matters here!! Not entirely sure why though.
    #url: '/todos'
    
    model: Todo
    
    sync: BackboneHTTP.sync(TodoList)
    
    getCompleted: =>
        @filter @_isCompleted

    getActive: =>
        @reject @_isCompleted
    
    comparator: (todo) ->
        todo.get "created"
    
    _isCompleted: (todo) ->
        todo.isCompleted()

#START Views


class window.ItemView extends Marionette.ItemView
  tagName: "li"
  
  template: "#template-todoItemView"
  
  #Marionette allows for "caching" of a UI element's jQuery analog
  ui:
    edit: ".edit"

  events:
    "click .destroy": "destroy"
    "dblclick label": "onEditClick"
    "keypress .edit": "onEditKeypress"
    "blur .edit": "onEditBlur"
    "click .toggle": "toggle"

  #Though Marionette takes care of rendering the view, we're calling render explicitly here when the model changes
  initialize: ->
    @listenTo @model, "change", @render

  onRender: ->
    @$el.removeClass "active completed"
    if @model.get("completed")
      @$el.addClass "completed"
    else
      @$el.addClass "active"

  destroy: ->
    #Instead of deleting the Mongo record entirely, we're going to "archive" it, so that
    #the BackboneORM query features can be demonstrated
    
    #@model.destroy()
    @model.archive().save {},
        success: =>
            app.collections.tds.remove(@model)
            console.log('todo archived')
        error: (model,xhr,options)->
            #We're swallowing the error here, but you shouldn't :)
            console.log('archive error: ' + xhr.responseText)
    
    
  #Mark the todo item as done  
  toggle: =>
    @model.toggle().save()

  onEditClick: ->
    @$el.addClass "editing"
    @ui.edit.focus()

  updateTodo: ->
    todoText = @ui.edit.val()
    
    #If the text has been removed, and submitted, archive the todo item
    return @destroy() if todoText is ""
    
    @setTodoText todoText
    @completeEdit()

  onEditBlur: (e) ->
    @updateTodo()

  onEditKeypress: (e) ->
    ENTER_KEY = 13
    @updateTodo()  if e.which is ENTER_KEY

  setTodoText: (todoText) ->
    return if todoText.trim() is ""
    @model.set("title", todoText).save()

  completeEdit: ->
    @$el.removeClass "editing"


#Main TODO list View
class window.ListView extends Backbone.Marionette.CompositeView
  
  template: "#template-todoListCompositeView"
  
  itemView: window.ItemView
  
  itemViewContainer: "#todo-list"
  
  ui:
    toggle: "#toggle-all"

  events:
    "click #toggle-all": "onToggleAllClick"

  initialize: ->
    @listenTo @collection, "all", @update

  onRender: ->
    @update()

  update: ->
    reduceCompleted = (left, right) ->
      left and right.get("completed")
    allCompleted = @collection.reduce(reduceCompleted, true)
    @ui.toggle.prop "checked", allCompleted
    @$el.parent().toggle !!@collection.length

  onToggleAllClick: (e) ->
    isChecked = e.currentTarget.checked
    @collection.each (todo) ->
      todo.save completed: isChecked

class window.ListHeader extends Backbone.Marionette.ItemView
  template: "#template-header"
  
  # UI bindings create cached attributes that
  # point to jQuery selected objects
  ui:
    input: "#new-todo"

  events:
    "keypress #new-todo": "onInputKeypress"
    "blur #new-todo": "onTodoBlur"

  onTodoBlur: ->
    todoText = @ui.input.val().trim()
    @createTodo todoText

  onInputKeypress: (e) ->
    ENTER_KEY = 13
    todoText = @ui.input.val().trim()
    @createTodo todoText  if e.which is ENTER_KEY and todoText

  completeAdd: ->
    @ui.input.val ""

  createTodo: (todoText) ->
    return  if todoText.trim() is ""
    @collection.create title: todoText
    @completeAdd()

class window.ListFilters extends Backbone.Marionette.ItemView
  template: "#template-todoListFilters"
  
  events:
    'click #btnGo': 'searchArchivedByDate'
  
  ui:
    dateFrom: ".txtDateFrom"
    dateTo: ".txtDateTo"
    btnGo: "#btnGo"
  
  onRender: =>
    @ui.dateFrom.datepicker()
    @ui.dateTo.datepicker()
    
  searchArchivedByDate: =>
    dateFrom = Date.parse(@ui.dateFrom.val())
    dateTo = Date.parse(@ui.dateTo.val())
    
    Todo.find {archived: true, created: {$gte: dateFrom.valueOf(), $lt: dateTo.valueOf()}}, (err,todos)->
      console.log(err) if err
      app.collections.tds.reset(todos or [])

#Start App

window.TodoMVC = new Backbone.Marionette.Application()
window.app = {}
window.app.collections = {}

TodoMVC.addRegions
    header: '#header'
    main: '#main'
    footer: '#footer'
    filters: '#filters'
    
#Allows us to configure some of the moving parts of our app -- runs when we call
#start() on the Marionette App instance (below)
TodoMVC.addInitializer (options)->
    app.collections.tds = new TodoList()
    lv = new ListView(collection: app.collections.tds)
    hv = new ListHeader(collection: app.collections.tds)
    lf = new ListFilters()
    
    TodoMVC.header.show(hv)
    TodoMVC.main.show(lv)
    TodoMVC.filters.show(lf)

#Fires after all of the initializers have finished
TodoMVC.on 'initialize:after', ->
  Backbone.history.start()
  #If you're having issues with the Backbone ORM query, you can 
  #just fetch the todo collection normally
  #app.collections.tds.fetch()
  
  #Obviously, you don't have to specify a date range on the created property
  Todo.find {archived: false}, (err,todos)->
      console.log(err) if err
      app.collections.tds.add(todos or [])
      
$(document).ready ->
    #Start the TodoMVC (Backbone.Marionette) app
    TodoMVC.start()
    
    