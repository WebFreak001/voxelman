/**
Copyright: Copyright (c) 2016 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.blockentity.utils;

import std.experimental.logger;
import std.array : Appender;
import voxelman.block.utils;
import voxelman.core.config;
import voxelman.core.events;
import voxelman.blockentity.blockentityaccess;
import voxelman.world.storage.coordinates;
import voxelman.world.storage.volume;


alias BlockEntityMeshhandler = void function(
	ref Appender!(ubyte[]) output,
	BlockEntityData data,
	ubyte[3] color, ubyte bx, ubyte by, ubyte bz,
	ubyte sides);

alias SolidityHandler = Solidity function(Side side);
alias EntityBoxHandler = Volume function(BlockWorldPos bwp, BlockEntityData data);
Volume nullBoxHandler(BlockWorldPos bwp, BlockEntityData data)
{
	return Volume(bwp.xyz, ivec3(1,1,1), cast(ushort)bwp.w);
}

void nullBlockEntityMeshhandler(
	ref Appender!(ubyte[]) output, BlockEntityData data,
	ubyte[3] color, ubyte bx, ubyte by, ubyte bz, ubyte sides) {}
Solidity nullSolidityHandler(Side side) {
	return Solidity.transparent;
}

struct BlockEntityInfo
{
	string name;
	BlockEntityMeshhandler meshHandler;
	SolidityHandler sideSolidity;
	EntityBoxHandler boxHandler;
	ubyte[3] color;
	//bool isVisible = true;
	size_t id;
}
BlockEntityInfo unknownBlockEntity =
	BlockEntityInfo("Unknown",
		&nullBlockEntityMeshhandler,
		&nullSolidityHandler,
		&nullBoxHandler);

struct BlockEntityInfoTable
{
	immutable(BlockEntityInfo)[] blockEntityInfos;
	size_t length() {return blockEntityInfos.length; }
	BlockEntityInfo opIndex(ushort blockEntityId) {
		blockEntityId = blockEntityId;
		if (blockEntityId >= blockEntityInfos.length)
			return unknownBlockEntity;
		return blockEntityInfos[blockEntityId];
	}
}
