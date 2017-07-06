/**
Copyright: Copyright (c) 2017 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module voxelman.gui.widgets;

import std.stdio;
import voxelman.gui;
import voxelman.math;
import voxelman.graphics;

void registerComponents(GuiContext ctx)
{
	ctx.widgets.registerComponent!TextButtonData;
}


enum baseColor = rgb(26, 188, 156);
enum hoverColor = rgb(22, 160, 133);
enum color_clouds = rgb(236, 240, 241);
enum color_silver = rgb(189, 195, 199);
enum color_concrete = rgb(149, 165, 166);
enum color_asbestos = rgb(127, 140, 141);

enum color_wet_asphalt = rgb(52, 73, 94);

struct Panel
{
	GuiContext ctx;

	WidgetId createPanel(WidgetId parent, ivec2 pos, ivec2 size, Color4ub color)
	{
		WidgetId panel = ctx.createWidget(
			parent,
			WidgetEvents(&drawWidget),
			WidgetTransform(pos, size),
			WidgetStyle(color));
		return panel;
	}

	void drawWidget(WidgetId wId, ref DrawEvent event)
	{
		if (event.sinking)
		{
			auto transform = ctx.widgets.getOrCreate!WidgetTransform(wId);
			auto style = ctx.widgets.get!WidgetStyle(wId);
			event.renderQueue.drawRectFill(vec2(transform.absPos), vec2(transform.size), event.depth, style.color);
			vec2 linePos = vec2(transform.absPos.x+transform.size.x, 0);
			event.renderQueue.drawRectFill(linePos, vec2(1, transform.size.y), event.depth, color_concrete);
			event.depth += 1;
			event.renderQueue.pushClipRect(irect(transform.absPos, transform.size));
		}
		else
		{
			event.renderQueue.popClipRect();
		}
	}
}


alias ClickHandler = void delegate();

@Component("gui.TextButtonData", Replication.none)
struct TextButtonData
{
	string text;
	ClickHandler handler;
	uint data;
}

enum BUTTON_PRESSED = 0b0001;
enum BUTTON_HOVERED = 0b0010;
enum BUTTON_SELECTED = 0b0100;

enum buttonNormalColor = rgb(255, 255, 255);
enum buttonHoveredColor = rgb(241, 241, 241);
enum buttonPressedColor = rgb(229, 229, 229);
Color4ub[4] buttonColors = [buttonNormalColor, buttonNormalColor, buttonHoveredColor, buttonPressedColor];

struct TextButton
{
	GuiContext ctx;

	WidgetId createButton(WidgetId parent, ivec2 pos, string text, ClickHandler handler)
	{
		WidgetId button = ctx.createWidget(parent,
			TextButtonData(text, handler),
			WidgetEvents(&drawWidget, &pointerMoved, &pointerPressed, &pointerReleased, &enterWidget, &leaveWidget, &clickWidget),
			WidgetTransform(pos, ivec2(100, 22)),
			WidgetStyle(baseColor),
			WidgetRespondsToPointer());
		return button;
	}

	void drawWidget(WidgetId wId, ref DrawEvent event)
	{
		if (event.sinking)
		{
			auto data = ctx.widgets.get!TextButtonData(wId);
			auto transform = ctx.widgets.getOrCreate!WidgetTransform(wId);
			auto style = ctx.widgets.get!WidgetStyle(wId);

			auto mesherParams = event.renderQueue.startTextAt(vec2(transform.absPos) + vec2(5,5));
			mesherParams.depth = event.depth+1;
			mesherParams.color = color_wet_asphalt;
			mesherParams.meshText(data.text);

			event.renderQueue.drawRectFill(vec2(transform.absPos), vec2(transform.size), event.depth, buttonColors[data.data]);
			event.debugText.putfln("Draw button: %s %s", wId, *transform);
			event.depth += 2;
		}
	}

	bool pointerMoved(WidgetId wId, PointerMoveEvent event) { return true; }

	bool pointerPressed(WidgetId wId, PointerPressEvent event)
	{
		//writefln("press %s", wId);
		ctx.widgets.get!TextButtonData(wId).data |= BUTTON_PRESSED;
		return true;
	}

	bool pointerReleased(WidgetId wId, PointerReleaseEvent event)
	{
		//writefln("release %s", wId);
		ctx.widgets.get!TextButtonData(wId).data &= ~BUTTON_PRESSED;
		return true;
	}

	bool enterWidget(WidgetId wId, ref PointerEnterEvent event)
	{
		//writefln("enter %s", wId);
		ctx.widgets.get!TextButtonData(wId).data |= BUTTON_HOVERED;
		return true;
	}

	bool leaveWidget(WidgetId wId, ref PointerLeaveEvent event)
	{
		//writefln("leave %s", wId);
		ctx.widgets.get!TextButtonData(wId).data &= ~BUTTON_HOVERED;
		return true;
	}

	bool clickWidget(WidgetId wId, ref PointerClickEvent event)
	{
		//writefln("click %s", wId);
		auto data = ctx.widgets.get!TextButtonData(wId);
		if (data.handler) data.handler();
		return true;
	}
}

struct RadioTextButton
{

}
