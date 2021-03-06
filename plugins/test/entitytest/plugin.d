/**
Copyright: Copyright (c) 2015-2017 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module test.entitytest.plugin;

import voxelman.log;
import voxelman.container.buffer;
import dlib.math;

import pluginlib;
import datadriven;
import voxelman.core.events;
import voxelman.core.config : BlockId;
import voxelman.world.storage : BlockWorldPos;
import voxelman.text.textformatter;

import voxelman.dbg.plugin;
import voxelman.edit.plugin;
import voxelman.entity.plugin;
import voxelman.eventdispatcher.plugin;
import voxelman.net.plugin;
import voxelman.worldinteraction.plugin;
import voxelman.world.serverworld;
import voxelman.world.storage;

import voxelman.edit.tools.itool;


final class EntityTestPlugin(bool clientSide) : IPlugin
{
	// IPlugin stuff
	mixin IdAndSemverFrom!"test.entitytest.plugininfo";

	EntityManager* eman;
	Debugger dbg;

	override void registerResources(IResourceManagerRegistry resmanRegistry)
	{
		auto compRegistry = resmanRegistry.getResourceManager!EntityComponentRegistry;
		eman = compRegistry.eman;
		eman.registerComponent!SandTransform();

		dbg = resmanRegistry.getResourceManager!Debugger;
	}

	static if (clientSide)
		mixin EntityTestPluginClient;
	else
		mixin EntityTestPluginServer;
}

mixin template EntityTestPluginClient()
{
	import voxelman.graphics.plugin;

	Batch batch;
	EventDispatcherPlugin evDispatcher;
	GraphicsPlugin graphics;
	WorldInteractionPlugin worldInteraction;
	NetClientPlugin connection;

	override void init(IPluginManager pluginman)
	{
		graphics = pluginman.getPlugin!GraphicsPlugin;
		evDispatcher = pluginman.getPlugin!EventDispatcherPlugin;
		evDispatcher.subscribeToEvent(&drawEntities);
		evDispatcher.subscribeToEvent(&process);
		worldInteraction = pluginman.getPlugin!WorldInteractionPlugin;
		connection = pluginman.getPlugin!NetClientPlugin;
		connection.registerPacket!EntityCreatePacket();

		auto editPlugin = pluginman.getPlugin!EditPlugin;
		editPlugin.registerTool(
			new class ITool
			{
				this() { name = "test.sand_entity"; }
				override void onMainActionRelease() {
					placeEntity();
				}

				override void onUpdate() {
					worldInteraction.drawCursor(worldInteraction.sideBlockPos, Colors.green);
				}
			}
		);
	}

	void placeEntity()
	{
		if (worldInteraction.cursorHit) {
			ivec4 pos = worldInteraction.sideBlockPos.vector;
			connection.send(EntityCreatePacket(pos));
		}
	}

	void process(ref ProcessComponentsEvent event)
	{
		batch.reset();
		auto query = eman.query!SandTransform();
		foreach(eid, sandTransform; query)
		{
			batch.putCube(vec3(sandTransform.pos), vec3(1,1,1), Color4ub(225, 169, 95), true);
		}
		dbg.setVar("Sand entities", eman.getComponentStorage!SandTransform().length);
	}

	void drawEntities(ref RenderSolid3dEvent event)
	{
		graphics.draw(batch);
	}
}

mixin template EntityTestPluginServer()
{
	EventDispatcherPlugin evDispatcher;
	NetServerPlugin connection;
	ServerWorld serverWorld;
	EntityPluginServer entityPlugin;
	Buffer!EntityId entitiesToRemove;

	override void init(IPluginManager pluginman)
	{
		evDispatcher = pluginman.getPlugin!EventDispatcherPlugin;
		evDispatcher.subscribeToEvent(&process);
		connection = pluginman.getPlugin!NetServerPlugin;
		connection.registerPacket!EntityCreatePacket(&handleEntityCreatePacket);
		serverWorld = pluginman.getPlugin!ServerWorld;
		entityPlugin = pluginman.getPlugin!EntityPluginServer;
	}

	void process(ref ProcessComponentsEvent event)
	{
		auto wa = serverWorld.worldAccess;
		auto query = eman.query!SandTransform();
		bool isFree(ivec4 pos) {
			return wa.isFree(BlockWorldPos(pos));
		}
		bool isLoaded(ivec4 pos) {
			return wa.getBlock(BlockWorldPos(pos)) != 0;
		}

		foreach(eid, sandTransform; query)
		{
			ivec4 pos = sandTransform.pos;
			if (!isLoaded(pos) || !isLoaded(pos+ivec4(0, -1, 0, 0))) continue;
			if (isFree(pos+ivec4(0, -1, 0, 0))) // lower
			{
				sandTransform.pos += ivec4(0,-1,0, 0);
			}
			else if (isFree(pos+ivec4( 0, 0, -1, 0)) && // side and lower
					isFree(pos+ivec4( 0, -1, -1, 0)))
			{
				sandTransform.pos = pos+ivec4( 0, 0, -1, 0);
			}
			else if (isFree(pos+ivec4( 0, 0,  1, 0)) && // side and lower
					isFree(pos+ivec4( 0, -1,  1, 0)))
			{
				sandTransform.pos = pos+ivec4( 0, 0,  1, 0);
			}
			else if (isFree(pos+ivec4(-1, 0,  0, 0)) && // side and lower
					isFree(pos+ivec4(-1, -1,  0, 0)))
			{
				sandTransform.pos = pos+ivec4(-1, 0,  0, 0);
			}
			else if (isFree(pos+ivec4( 1, 0,  0, 0)) && // side and lower
					isFree(pos+ivec4( 1, -1,  0, 0)))
			{
				sandTransform.pos = pos+ivec4( 1, 0,  0, 0);
			}
			else // set sand
			{
				wa.setBlock(BlockWorldPos(pos), BlockId(5));
				entitiesToRemove.put(eid);
			}
			entityPlugin.entityObserverManager.updateEntityPos(
				eid,
				ChunkWorldPos(BlockWorldPos(sandTransform.pos)));
		}

		auto storage = eman.getComponentStorage!SandTransform();
		foreach(eid; entitiesToRemove.data) {
			storage.remove(eid);
			entityPlugin.entityObserverManager.removeEntity(eid);
		}
		entitiesToRemove.clear();
	}

	void handleEntityCreatePacket(ubyte[] packetData, SessionId sessionId)
	{
		auto packet = unpackPacket!EntityCreatePacket(packetData);
		EntityId eid = eman.eidMan.nextEntityId;
		eman.set(eid, SandTransform(packet.pos));
		entityPlugin.entityObserverManager.addEntity(eid, ChunkWorldPos(BlockWorldPos(packet.pos)));
	}
}

@Component("component.SandTransform", Replication.toDb | Replication.toClient)
struct SandTransform
{
	ivec4 pos;
}

struct EntityCreatePacket
{
	ivec4 pos;
}
