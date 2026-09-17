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

// ListPrimitives.as
// Who knows?
//
// Online wrapper around list primitives, adding support for cloud lists.

package primitives {
	import interpreter.Interpreter;
	import watchers.ListWatcher;

public class ListPrimsOnline extends ListPrims {

	public function ListPrimsOnline(app:Scratch, interpreter:Interpreter) {
		super(app, interpreter);
	}

	override protected function listAppend(list:ListWatcher, item:*):void {
		super.listAppend(list, item);
		if (list.isPersistent) {
			ScratchOnline.app.persistenceManager.appendList(list.listName, item);
		}
	}

	override protected function listSet(list:ListWatcher, newValue:Array):void {
		super.listSet(list, newValue);
		if (list.isPersistent) {
			ScratchOnline.app.persistenceManager.setList(list.listName, newValue.contents);
		}
	}

	override protected function listDelete(list:ListWatcher, i:int):void {
		super.listDelete(list, i);
		if (list.isPersistent) {
			ScratchOnline.app.persistenceManager.deleteList(list.listName, i);
		}
	}

	override protected function listInsert(list:ListWatcher, i:int, item:*):void {
		super.listInsert(list, i, item);
		if (list.isPersistent) {
			// Note how params 2 and 3 are swapped
			ScratchOnline.app.persistenceManager.insertList(list.listName, item, i);
		}
	}

	override protected function listReplace(list:ListWatcher, i:int, item:*):void {
		super.listReplace(list, i, item);
		if (list.isPersistent) {
			// Note how params 2 and 3 are swapped
			ScratchOnline.app.persistenceManager.replaceList(list.listName, item, i);
		}
	}
}
}
