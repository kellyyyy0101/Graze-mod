/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// InterpreterOnline.as
// Who knows?
//
// Online wrapper around the interpreter.
//

package interpreter {
import blocks.*;
import flash.external.ExternalInterface;
import flash.utils.*;
import primitives.*;

public class InterpreterOnline extends Interpreter {

	private var opCount:uint;

	public function InterpreterOnline(app:Scratch)
	{
		super(app);
		this.opCount = 0;
		if (ScratchOnline.app.debugOps && ScratchOnline.app.jsEnabled) {
			debugFunc = this.debugBlock;
		}
	}

	override public function stopAllThreads():void {
		super.stopAllThreads();
		this.opCount = 0;
	}

	private function debugBlock(b:Block):void {
		var args:Array = b.args;
		var extArgs:Array = new Array(args.length);

		for (var i:uint; i < args.length; i++) {
			extArgs[i] = arg(b, i);
		}

		ExternalInterface.call(ScratchOnline.app.debugOpCmd, this.opCount, b.op, extArgs);
		++this.opCount;
	}

	override protected function primVarSet(b:Block):Variable {
		var v:Variable = super.primVarSet(b);
		if (Boolean(v) && v.isPersistent) {
			// Handle cloud variables
			ScratchOnline.app.persistenceManager.updateVariable(v.name, v.value);
		}
		return v;
	}

	override protected function primVarChange(b:Block):Variable {
		var v:Variable = super.primVarChange(b);
		if (Boolean(v) && v.isPersistent) {
			// Handle cloud variables
			ScratchOnline.app.persistenceManager.updateVariable(v.name, v.value);
		}
		return v;
	}

	override protected function addOtherPrims(primTable:Dictionary):void {
		// Use PrimitivesOnline for other primitives
		new PrimitivesOnline(ScratchOnline.app, this).addPrimsTo(primTable);
	}
}
}
