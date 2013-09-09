define ["historyview", "controlbox", "d3"], (HistoryView, ControlBox, d3) ->
  prefix = "ExplainGit"
  openSandBoxes = []
  open = (args) ->
    name = prefix + args.name
    containerId = name + "-Container"
    container = d3.select("#" + containerId)
    playground = container.select(".playground-container")
    container.style "display", "block"
    args.name = name
    historyView = new HistoryView(args)
    if args.originData
      originView = new HistoryView(
        name: name + "-Origin"
        width: 300
        height: 225
        commitRadius: 15
        remoteName: "origin"
        commitData: args.originData
      )
      originView.render playground
    controlBox = new ControlBox(
      historyView: historyView
      originView: originView
      initialMessage: args.initialMessage
    )
    controlBox.render playground
    historyView.render playground
    openSandBoxes.push
      hv: historyView
      cb: controlBox
      container: container


  reset = ->
    i = 0

    while i < openSandBoxes.length
      osb = openSandBoxes[i]
      osb.hv.destroy()
      osb.cb.destroy()
      osb.container.style "display", "none"
      i++
    openSandBoxes.length = 0
    d3.selectAll("a.openswitch").classed "selected", false

  explainGit =
    HistoryView: HistoryView
    ControlBox: ControlBox
    generateId: HistoryView.generateId
    open: open
    reset: reset

  window.explainGit = explainGit
  explainGit
