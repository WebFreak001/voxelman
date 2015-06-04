/**
Copyright: Copyright (c) 2015 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module voxelman.client.plugins.worldinteractionplugin;

import std.experimental.logger;
import core.time;

import plugin;
import voxelman.config;

import voxelman.events;
import voxelman.packets;
import voxelman.storage.coordinates;

import voxelman.plugins.inputplugin;
import voxelman.plugins.eventdispatcherplugin;
import voxelman.plugins.graphicsplugin;
import voxelman.client.clientplugin;

class WorldInteractionPlugin : IPlugin
{
	ClientPlugin clientPlugin;
	EventDispatcherPlugin evDispatcher;
	GraphicsPlugin graphics;

	// Cursor
	bool cursorHit;
	BlockWorldPos blockPos;
	ivec3 hitNormal;

	// Cursor rendering stuff
	vec3 cursorPos, cursorSize = vec3(1.02, 1.02, 1.02);
	vec3 lineStart, lineEnd;
	bool traceVisible;
	bool showCursor = true;
	vec3 hitPosition;
	Duration cursorTraceTime;
	Batch traceBatch;
	Batch hitBatch;

	// IPlugin stuff
	override string name() @property { return "WorldInteractionPlugin"; }
	override string semver() @property { return "0.5.0"; }

	override void init(IPluginManager pluginman)
	{
		clientPlugin = pluginman.getPlugin!ClientPlugin(this);
		graphics = pluginman.getPlugin!GraphicsPlugin(this);

		evDispatcher = pluginman.getPlugin!EventDispatcherPlugin(this);
		evDispatcher.subscribeToEvent(&onUpdateEvent);
		evDispatcher.subscribeToEvent(&drawDebug);
	}

	void onUpdateEvent(UpdateEvent event)
	{
		traceCursor();
		drawDebugCursor();
	}

	void placeBlock(BlockType blockId)
	{
		if (clientPlugin.chunkMan.blockMan.blocks[blockId].isVisible)
		{
			blockPos.vector += hitNormal;
		}

		//infof("hit %s, blockPos %s, hitPosition %s, hitNormal %s\ntime %s",
		//	cursorHit, blockPos, hitPosition, hitNormal,
		//	cursorTraceTime.formatDuration);

		cursorPos = vec3(blockPos.vector) - vec3(0.005, 0.005, 0.005);
		lineStart = graphics.camera.position;
		lineEnd = graphics.camera.position + graphics.camera.target * 40;

		if (cursorHit)
		{
			hitBatch = traceBatch;
			traceBatch = Batch();

			traceVisible = true;
			clientPlugin.connection.send(PlaceBlockPacket(blockPos.vector, blockId));
		}
		else
		{
			traceVisible = false;
		}
	}

	BlockType pickBlock()
	{
		return clientPlugin.worldAccess.getBlock(blockPos);
	}

	void traceCursor()
	{
		StopWatch sw;
		sw.start();

		auto isBlockSolid = (ivec3 blockWorldPos) {
			auto block = clientPlugin.worldAccess.getBlock(BlockWorldPos(blockWorldPos));
			return clientPlugin.chunkMan
				.blockMan
				.blocks[block]
				.isVisible;
		};

		traceBatch.reset();

		cursorHit = traceRay(
			isBlockSolid,
			graphics.camera.position,
			graphics.camera.target,
			80.0, // max distance
			hitPosition,
			hitNormal,
			traceBatch);

		blockPos = BlockWorldPos(hitPosition);
		cursorTraceTime = cast(Duration)sw.peek;
	}

	void drawDebugCursor()
	{
		if (traceVisible)
		{
			traceBatch.putCube(cursorPos, cursorSize, Colors.black, false);
			traceBatch.putLine(lineStart, lineEnd, Colors.black);
		}

		if (showCursor)
		{
			graphics.debugBatch.putCube(
				vec3(blockPos.vector) - vec3(0.005, 0.005, 0.005),
				cursorSize, Colors.red, false);
			graphics.debugBatch.putCube(
				vec3(blockPos.vector+hitNormal) - vec3(0.005, 0.005, 0.005),
				cursorSize, Colors.blue, false);
		}
	}

	void drawDebug(Render1Event event)
	{
		graphics.chunkShader.bind;
		//graphics.draw(hitBatch);
		graphics.chunkShader.unbind;
	}
}