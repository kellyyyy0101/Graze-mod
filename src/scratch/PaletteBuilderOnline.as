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

// PaletteBuilderOnline.as
// Who knows?
//
// Wrapper around PaletteBuilder that adds cloud data support

package scratch {
import interpreter.PersistenceManager;

import uiwidgets.*;

public class PaletteBuilderOnline extends PaletteBuilder {

	public function PaletteBuilderOnline(app:Scratch) {
		super(app);
	}

	override protected function createVar(name:String, settings:VariableSettings):* {
		var varSettings:VariableSettingsOnline = settings as VariableSettingsOnline;
		if (varSettings.isPersistent) {
			var app:ScratchOnline = ScratchOnline.app;
			++app.persistentDataCount;
			name = "☁ " + name;

			if (!app.usesPersistentData) {
				app.usesPersistentData = true;
				app.persistenceManager.addEventListener(PersistenceManager.READY, function():void {
					if (settings.isList) {
						app.persistenceManager.setList(name, []);
					} else {
						app.persistenceManager.createVariable(name);
					}
				});
				app.persistenceManager.connect(app.serverSettings.cloud_data_host);
			} else if (settings.isList) {
				app.persistenceManager.setList(name, []);
			} else {
				app.persistenceManager.createVariable(name);
			}

			return;
		}
		var v:* = super.createVar(name, varSettings);
		return v;
	}

	override protected function makeVarSettings(isList:Boolean, isStage:Boolean):VariableSettings {
		return new VariableSettingsOnline(isList, isStage, ScratchOnline.app.isLoggedIn(), ScratchOnline.app.isScratcher());
	}
}
}
