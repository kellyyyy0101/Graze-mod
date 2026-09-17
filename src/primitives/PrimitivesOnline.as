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

// PrimitivesOnline.as
// Who knows?
//
// Wrapper around Primitives to use the Online primitives.

package primitives {
	import flash.utils.Dictionary;
	import interpreter.Interpreter;

public class PrimitivesOnline extends Primitives {

	public function PrimitivesOnline(app:Scratch, interpreter:Interpreter) {
		super(app, interpreter);
	}

	override protected function addOtherPrims(primTable:Dictionary):void {
		new SensingPrimsOnline(app, interp).addPrimsTo(primTable);
		new ListPrimsOnline(app, interp).addPrimsTo(primTable);
	}
}
}
