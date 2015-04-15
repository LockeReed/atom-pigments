path = require 'path'
ColorBufferElement = require '../lib/color-buffer-element'
ColorMarkerElement = require '../lib/color-marker-element'

describe 'ColorBufferElement', ->
  [editor, editorElement, colorBuffer, pigments, project, colorBufferElement, jasmineContent] = []

  editBuffer = (text, options={}) ->
    if options.start?
      if options.end?
        range = [options.start, options.end]
      else
        range = [options.start, options.start]

      editor.setSelectedBufferRange(range)

    editor.insertText(text)
    editor.getBuffer().emitter.emit('did-stop-changing') unless options.noEvent

  jsonFixture = (fixture, data) ->
    jsonPath = path.resolve(__dirname, 'fixtures', fixture)
    json = fs.readFileSync(jsonPath).toString()
    json = json.replace /#\{(\w+)\}/g, (m,w) -> data[w]

    JSON.parse(json)


  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    jasmineContent = document.body.querySelector('#jasmine-content')

    jasmineContent.appendChild(workspaceElement)

    atom.config.set 'pigments.sourceNames', [
      '*.styl'
      '*.less'
    ]

    waitsForPromise ->
      atom.workspace.open('four-variables.styl').then (o) ->
        editor = o
        editorElement = atom.views.getView(editor)

    waitsForPromise -> atom.packages.activatePackage('pigments').then (pkg) ->
      pigments = pkg.mainModule
      project = pigments.getProject()

  describe 'when an editor is opened', ->
    beforeEach ->
      colorBuffer = project.colorBufferForEditor(editor)
      colorBufferElement = atom.views.getView(colorBuffer)
      colorBufferElement.attach()

    it 'is associated to the ColorBuffer model', ->
      expect(colorBufferElement).toBeDefined()
      expect(colorBufferElement.getModel()).toBe(colorBuffer)

    it 'attaches itself in the target text editor element', ->
      expect(colorBufferElement.parentNode).toExist()
      expect(editorElement.shadowRoot.querySelector('.lines pigments-markers')).toExist()

    describe 'when the color buffer is initialized', ->
      beforeEach ->
        waitsForPromise -> colorBuffer.initialize()

      it 'creates markers views for every visible buffer markers', ->
        markersElements = colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker')

        expect(markersElements.length).toEqual(3)

        for marker in markersElements
          expect(marker.getModel()).toBeDefined()

      describe 'when the project variables are initialized', ->
        it 'creates markers for the new valid colors', ->
          waitsForPromise -> colorBuffer.variablesAvailable()
          runs ->
            expect(colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker').length).toEqual(4)

      describe 'when a selection intersects a marker range', ->
        beforeEach ->
          spyOn(colorBufferElement, 'updateSelections').andCallThrough()

        describe 'after the markers views was created', ->
          beforeEach ->
            waitsForPromise -> colorBuffer.variablesAvailable()
            runs -> editor.setSelectedBufferRange [[2,12],[2, 14]]
            waitsFor -> colorBufferElement.updateSelections.callCount > 0

          it 'hides the intersected marker', ->
            markers = colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker')

            expect(markers[0].style.display).toEqual('')
            expect(markers[1].style.display).toEqual('')
            expect(markers[2].style.display).toEqual('')
            expect(markers[3].style.display).toEqual('none')

        describe 'before all the markers views was created', ->
          beforeEach ->
            runs -> editor.setSelectedBufferRange [[0,0],[2, 14]]
            waitsFor -> colorBufferElement.updateSelections.callCount > 0

          it 'hides the existing markers', ->
            markers = colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker')

            expect(markers[0].style.display).toEqual('none')
            expect(markers[1].style.display).toEqual('')
            expect(markers[2].style.display).toEqual('')

          describe 'and the markers are updated', ->
            beforeEach ->
              waitsForPromise -> colorBuffer.variablesAvailable()

            it 'hides the created markers', ->
              markers = colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker')
              expect(markers[0].style.display).toEqual('none')
              expect(markers[1].style.display).toEqual('')
              expect(markers[2].style.display).toEqual('')
              expect(markers[3].style.display).toEqual('none')

      describe 'when some markers are destroyed', ->
        [spy] = []
        beforeEach ->
          for el in colorBufferElement.usedMarkers
            spyOn(el, 'release').andCallThrough()

          spy = jasmine.createSpy('did-update')
          colorBufferElement.onDidUpdate(spy)
          editBuffer '', start: [4,0], end: [8,0]
          waitsFor -> spy.callCount > 0

        it 'releases the unused markers', ->
          expect(colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker').length).toEqual(3)
          expect(colorBufferElement.usedMarkers.length).toEqual(2)
          expect(colorBufferElement.unusedMarkers.length).toEqual(1)

          for marker in colorBufferElement.unusedMarkers
            expect(marker.release).toHaveBeenCalled()

        describe 'and then a new marker is created', ->
          beforeEach ->
            editor.moveToBottom()
            editBuffer '\nfoo = #123456\n'
            waitsFor -> colorBufferElement.unusedMarkers.length is 0

          it 'reuses the previously released marker element', ->
            expect(colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker').length).toEqual(3)
            expect(colorBufferElement.usedMarkers.length).toEqual(3)
            expect(colorBufferElement.unusedMarkers.length).toEqual(0)

      describe 'when the current pane is splitted to the right', ->
        beforeEach ->
          atom.commands.dispatch(editorElement, 'pane:split-right')
          editor = atom.workspace.getTextEditors()[1]
          colorBufferElement = atom.views.getView(project.colorBufferForEditor(editor))
          waitsFor ->
            colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker').length

        it 'should keep all the buffer elements attached', ->
          editors = atom.workspace.getTextEditors()

          editors.forEach (editor) ->
            editorElement = atom.views.getView(editor)
            colorBufferElement = editorElement.shadowRoot.querySelector('pigments-markers')
            expect(colorBufferElement).toExist()

            expect(colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker').length).toEqual(3)
            expect(colorBufferElement.shadowRoot.querySelectorAll('pigments-color-marker:empty').length).toEqual(0)
