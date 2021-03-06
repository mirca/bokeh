import * as _ from "underscore"

import {Annotation, AnnotationView} from "./annotation"
import * as p from "../../core/properties"

export class BoxAnnotationView extends AnnotationView
  initialize: (options) ->
    super(options)
    @$el.appendTo(@plot_view.$el.find('div.bk-canvas-overlays'))
    @$el.addClass('bk-shading')
    @$el.hide()

  bind_bokeh_events: () ->
    # need to respond to either normal BB change events or silent
    # "data only updates" that tools might want to use
    if @model.render_mode == 'css'
      # dispatch CSS update immediately
      @listenTo(@model, 'change', @render)
      @listenTo(@model, 'data_update', @render)
    else
      @listenTo(@model, 'change', @plot_view.request_render)
      @listenTo(@model, 'data_update', @plot_view.request_render)

  render: () ->
    # don't render if *all* position are null
    if not @model.left? and not @model.right? and not @model.top? and not @model.bottom?
      @$el.hide()
      return null

    @frame = @plot_model.frame
    @canvas = @plot_model.canvas
    @xmapper = @plot_view.frame.x_mappers[@model.x_range_name]
    @ymapper = @plot_view.frame.y_mappers[@model.y_range_name]

    sleft   = @canvas.vx_to_sx(@_calc_dim(@model.left,   @model.left_units,   @xmapper, @frame.h_range.start))
    sright  = @canvas.vx_to_sx(@_calc_dim(@model.right,  @model.right_units,  @xmapper, @frame.h_range.end))
    sbottom = @canvas.vy_to_sy(@_calc_dim(@model.bottom, @model.bottom_units, @ymapper, @frame.v_range.start))
    stop    = @canvas.vy_to_sy(@_calc_dim(@model.top,    @model.top_units,    @ymapper, @frame.v_range.end))

    if @model.render_mode == 'css'
      @_css_box(sleft, sright, sbottom, stop)
    else
      @_canvas_box(sleft, sright, sbottom, stop)

  _css_box: (sleft, sright, sbottom, stop) ->
    sw = Math.abs(sright-sleft)
    sh = Math.abs(sbottom-stop)

    lw = @model.line_width.value
    lc = @model.line_color.value
    bc = @model.fill_color.value
    ba = @model.fill_alpha.value
    style = "left:#{sleft}px; width:#{sw}px; top:#{stop}px; height:#{sh}px; border-width:#{lw}px; border-color:#{lc}; background-color:#{bc}; opacity:#{ba};"
    # try our best to honor line dashing in some way, if we can
    ld = @model.line_dash
    if _.isArray(ld)
      if ld.length < 2
        ld = "solid"
      else
        ld = "dashed"
    if _.isString(ld)
      style += " border-style:#{ld};"
    @$el.attr('style', style)
    @$el.show()

  _canvas_box: (sleft, sright, sbottom, stop) ->
    ctx = @plot_view.canvas_view.ctx
    ctx.save()

    ctx.beginPath()
    ctx.rect(sleft, stop, sright-sleft, sbottom-stop)

    @visuals.fill.set_value(ctx)
    ctx.fill()

    @visuals.line.set_value(ctx)
    ctx.stroke()

    ctx.restore()

  _calc_dim: (dim, dim_units, mapper, frame_extrema) ->
    if dim?
      if dim_units == 'data'
        vdim = mapper.map_to_target(dim)
      else
        vdim = dim
    else
      vdim = frame_extrema
    return vdim

export class BoxAnnotation extends Annotation
  default_view: BoxAnnotationView

  type: 'BoxAnnotation'

  @mixins ['line', 'fill']

  @define {
      render_mode:  [ p.RenderMode,   'canvas'  ]
      x_range_name: [ p.String,       'default' ]
      y_range_name: [ p.String,       'default' ]
      top:          [ p.Number,       null      ]
      top_units:    [ p.SpatialUnits, 'data'    ]
      bottom:       [ p.Number,       null      ]
      bottom_units: [ p.SpatialUnits, 'data'    ]
      left:         [ p.Number,       null      ]
      left_units:   [ p.SpatialUnits, 'data'    ]
      right:        [ p.Number,       null      ]
      right_units:  [ p.SpatialUnits, 'data'    ]
  }

  @override {
    fill_color: '#fff9ba'
    fill_alpha: 0.4
    line_color: '#cccccc'
    line_alpha: 0.3
  }

  update:({left, right, top, bottom}) ->
    @setv({left: left, right: right, top: top, bottom: bottom}, {silent: true})
    @trigger('data_update')
