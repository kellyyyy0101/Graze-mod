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

// TopBarPart.as
// John Maloney, November 2011
//
// Wrapper around TopBarPart that adds online-exclusive buttons.


package ui.parts {
import assets.Resources;
import flash.display.*;
import flash.events.MouseEvent;
import flash.net.*;
import flash.text.*;
import flash.utils.Dictionary;
import translation.Translator;
import uiwidgets.*;

public class TopBarPartOnline extends TopBarPart {

	[Embed(source="../../assets/exclamationIcon.png")] private static const exclamationIcon:Class;

	private const saveStatusFormat:TextFormat = new TextFormat(CSS.font, 11, CSS.white, false);
	private const saveStatusAlertFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.white, true);

	private var tipsButton:IconButton;
	private var aboutButton:IconButton;
	private var signInMenu:IconButton;
	private var joinButton:IconButton;
	private var myStuffButton:IconButton;
	private var remixButton:IconButton;
	private var projectPageButton:IconButton;
	private var shareButton:IconButton;
	private var openInScratchButton:IconButton;

	private var shareForbiddenFlag:DisplayObject;
	private var saveStatus:TextField;
	private var transitionNotice:Sprite;
	private var websiteButton:IconButton;

	public function TopBarPartOnline(app:Scratch, isEmbedded:Boolean) {
		super(app);

		if (isEmbedded) {
			fileMenu.visible = false;
			editMenu.visible = false;
			this.tipsButton.visible = false;
			this.aboutButton.visible = false;
			this.websiteButton.visible = !app.isMicroworld;
		}
	}

	public static function strings():Array {
		if (Scratch.app) {
			ScratchOnline.app.signInPressed(Menu.dummyButton());
		}
		return ['Tips', 'Sign in', 'See project page', 'Remix', 'Share', 'About', 'Save a copy of this project and add your own ideas.'];
	}

	override protected function addButtons():void {
		super.addButtons();

		if (!app.isExtensionDevMode) {
			this.addLogo();
		}

		this.addMyStuffButton();
		this.addProjectButton();
		this.addRemixButton();
		this.addShareButton();
		this.addSaveStatus();
		this.addEmbeddedEditorButton();
		this.addOpenInScratchButton();

		if (app.isMicroworld) {
			for (var i:int = 0; i < this.numChildren; i++) {
				this.getChildAt(i).visible = false;
			}
		}
	}

	override protected function removeTextButtons():void {
		super.removeTextButtons();

		if (this.tipsButton.parent) {
			removeChild(this.tipsButton);
			removeChild(this.aboutButton);
			removeChild(this.signInMenu);
			removeChild(this.joinButton);
			removeChild(this.projectPageButton);
			removeChild(this.remixButton);
			removeChild(this.shareButton);
		}
	}

	override public function updateTranslation():void {
		super.updateTranslation();

		this.addProjectButton();
		this.addRemixButton();
		this.addShareButton();
		this.refresh();
	}

	override protected function fixLogoLayout():int {
		if (app.isExtensionDevMode) return super.fixLogoLayout();

		var nextX:int = 0;
		if (logoButton) {
			logoButton.x = nextX;
			logoButton.y = 2;
			nextX += logoButton.width + 9;
		}
		return nextX;
	}

	override protected function fixLayout():void {
		super.fixLayout();

		var nextX:int = editMenu.x + editMenu.width;
		var nextY:int = editMenu.y;

		if (this.tipsButton.visible) {
			nextX += buttonSpace + this.tipsButton.width;
			this.tipsButton.x = nextX - this.tipsButton.width;
			this.tipsButton.y = nextY;
		}

		if (this.aboutButton.visible) {
			nextX += buttonSpace + this.aboutButton.width;
			this.aboutButton.x = nextX - this.aboutButton.width;
			this.aboutButton.y = nextY;
		}

		nextX = w;

		if (this.websiteButton.visible) {
			nextX -= this.websiteButton.width + 3;
			this.websiteButton.x = nextX;
			this.websiteButton.y = nextY - 2;
		}

		if (this.signInMenu.visible) {
			nextX -= this.signInMenu.width + 8;
			this.signInMenu.x = nextX;
			this.signInMenu.y = nextY;
		}

		if (this.myStuffButton.visible) {
			nextX -= this.myStuffButton.width + 8;
			this.myStuffButton.x = nextX;
			this.myStuffButton.y = nextY;
		}

		if (this.joinButton.visible) {
			nextX -= this.joinButton.width + 8;
			this.joinButton.x = nextX;
			this.joinButton.y = nextY;
		}

		nextX = w;
		nextY = h + 5;

		if (this.projectPageButton.visible) {
			nextX -= this.projectPageButton.width + 5;
			this.projectPageButton.x = nextX;
			this.projectPageButton.y = nextY;
		}

		if (this.remixButton.visible) {
			nextX -= this.remixButton.width + 5;
			this.remixButton.x = nextX;
			this.remixButton.y = nextY;
		}

		if (this.shareButton.visible) {
			nextX -= this.shareButton.width + 5;
			this.shareButton.x = nextX;
			this.shareButton.y = nextY;
			this.shareForbiddenFlag.x = this.shareButton.x + this.shareButton.width - this.shareForbiddenFlag.width * 0.75;
			this.shareForbiddenFlag.y = this.shareButton.y - this.shareForbiddenFlag.height * 0.25;
		}

		if (app.isMicroworld) {
			nextX -= this.openInScratchButton.width + 5;
			this.openInScratchButton.x = nextX;
		}

		this.fixStatusLayout();
	}

	override public function refresh():void {
		this.projectPageButton.visible = app.projectID != "" && !app.isMicroworld;
		this.signInMenu.visible = true;
		this.setUserName(ScratchOnline.app.isLoggedIn() ? ScratchOnline.app.userName : Translator.map("Sign in"));

		if (ScratchOnline.app.isLoggedIn() && app.projectID != "") {
			if (app.isMicroworld) {
				this.myStuffButton.visible = false;
				this.remixButton.visible = false;
				this.shareButton.visible = false;
				this.signInMenu.visible = false;
				this.projectPageButton.visible = false;
			} else {
				this.myStuffButton.visible = true;
				this.remixButton.visible = app.projectOwner != ScratchOnline.app.userName;
				this.shareButton.visible = !this.remixButton.visible && app.projectIsPrivate;
			}
		} else if (ScratchOnline.app.isEmbedded && !ScratchOnline.app.isMicroworld || app.isOffline) {
			this.myStuffButton.visible = false;
			this.remixButton.visible = false;
			this.projectPageButton.visible = false;
			this.shareButton.visible = false;
			this.signInMenu.visible = false;
		} else {
			this.myStuffButton.visible = false;
			this.remixButton.visible = app.projectID != "" && app.projectOwner != ScratchOnline.app.userName;
			this.shareButton.visible = false;
			this.signInMenu.visible = !app.isMicroworld;
		}

		if (ScratchOnline.app.serverSettings) {
			this.shareForbiddenFlag.visible = this.shareButton.visible && !ScratchOnline.app.serverSettings.user_is_social;
		} else {
			this.shareForbiddenFlag.visible = false;
		}

		this.joinButton.visible = this.signInMenu.visible && !ScratchOnline.app.isLoggedIn();
		this.openInScratchButton.visible = Scratch.app.isMicroworld && ScratchOnline.app.isLoggedIn();

		super.refresh();
	}

	private function addLogo():void {
		logoButton = new IconButton(app.logoButtonPressed, 'scratchlogo');
		logoButton.isMomentary = true;
		addChild(logoButton);
	}

	override protected function addTextButtons():void {
		function aboutClicked (ignore:*):void {
			if (ScratchOnline.app.isEmbedded || app.isOffline) {
				// Oh no, an hardcoded URL!
				navigateToURL(new URLRequest(ScratchOnline.app.hostProtocol + '://scratch.mit.edu/about/'));
			} else {
				ScratchOnline.app.saveAndRedirectTo('about');
			}
		}

		function showTipsWindow(param1:*):void {
			ScratchOnline.app.showTip('home');
		}

		super.addTextButtons();
		addChild(this.tipsButton = makeMenuButton('Tips', showTipsWindow, false, 0x000000));
		addChild(this.aboutButton = makeMenuButton('About', aboutClicked, false, 0x000000));
		addChild(this.signInMenu = makeMenuButton('Sign in', ScratchOnline.app.signInPressed, true, 0x000000));
		addChild(this.joinButton = makeMenuButton('Join Scratch', ScratchOnline.app.joinPressed, false, 0x000000));
	}

	private function addMyStuffButton():void {
		addChild(this.myStuffButton = new IconButton(ScratchOnline.app.myStuffPressed, 'myStuff'));
		this.myStuffButton.isMomentary = true;
	}

	private function addProjectButton():void {
		this.projectPageButton = new IconButton(ScratchOnline.app.returnToProjectPage, this.makeFlipButtonImg(true), this.makeFlipButtonImg(false));
		this.projectPageButton.isMomentary = true;
		addChild(this.projectPageButton);
	}

	private function addRemixButton():void {
		var c:int = CSS.buttonLabelOverColor;
		this.remixButton = new IconButton(ScratchOnline.app.remixButtonPressed, makeButtonImg('Remix', c, true), makeButtonImg('Remix', c, false));
		this.remixButton.isMomentary = true;

		SimpleTooltips.add(this.remixButton, {
			'text': 'Save a copy of this project and add your own ideas.',
			'direction': 'bottom'
		});

		addChild(this.remixButton);
	}

	private function addShareButton():void {
		var c:int = CSS.topBarColor();
		this.shareButton = new IconButton(ScratchOnline.app.shareButtonPressed, makeButtonImg('Share', c, true), makeButtonImg('Share', c, false));
		this.shareButton.isMomentary = true;
		addChild(this.shareButton);

		this.shareForbiddenFlag = new exclamationIcon();
		this.shareForbiddenFlag.visible = false;
		addChild(this.shareForbiddenFlag);
	}

	private function addEmbeddedEditorButton():void {
		function showWebsite(b:IconButton):void {
			// Yet another hardcoded url
			navigateToURL(new URLRequest('http://scratch.mit.edu'));
		}

		var c:int = CSS.overColor;
		this.websiteButton = new IconButton(showWebsite, makeButtonImg('Go to scratch.mit.edu', c, true), makeButtonImg('Go to scratch.mit.edu', c, false));
		this.websiteButton.isMomentary = true;
		addChild(this.websiteButton);
		this.websiteButton.visible = false;
	}

	private function addOpenInScratchButton():void {
		this.openInScratchButton = new IconButton(ScratchOnline.app.openInScratch, this.makeOpenInScratchButtonImg(true), this.makeOpenInScratchButtonImg(false));
		addChild(this.openInScratchButton);
	}

	// See TopBarPart.makeButtonImg
	private function makeFlipButtonImg(isOn:Boolean):Sprite {
		var result:Sprite = new Sprite();

		var label:TextField = makeLabel(Translator.map("See project page"), CSS.topBarButtonFormat, 2, 2);
		label.textColor = CSS.white;
		result.addChild(label);

		var w:int = label.textWidth + 44;
		var h:int = 22;
		var g:Graphics = result.graphics;
		g.clear();
		g.beginFill(CSS.overColor);
		g.drawRoundRect(0, 0, w, h, 8, 8);
		g.endFill();

		var icon:Bitmap = Resources.createBmp("projectPageFlip");
		icon.x = 5;
		icon.y = -1;
		result.addChild(icon);
		label.x = icon.x + icon.width + 1;

		return result;
	}

	// See TopBarPart.makeButtonImg
	private function makeOpenInScratchButtonImg(isOn:Boolean):Sprite {
		var result:Sprite = new Sprite();

		var label:TextField = makeLabel(Translator.map("Save and open in Scratch"), CSS.topBarButtonFormat, 2, 2);
		label.textColor = CSS.white;
		result.addChild(label);

		var w:int = label.textWidth + 35;
		var h:int = 22;
		var g:Graphics = result.graphics;
		g.clear();
		g.beginFill(CSS.overColor);
		g.drawRoundRect(0, 0, w, h, 8, 8);
		g.endFill();

		label.x = 5;
		var icon:Bitmap = Resources.createBmp("openInScratch");
		icon.x = label.width + label.x + 5;
		icon.y = 11 - icon.height / 2;
		result.addChild(icon);

		return result;
	}

	private function setUserName(username:String):void {
		var onImage:Sprite = makeButtonLabel(username, CSS.buttonLabelOverColor, true);
		var offImage:Sprite = makeButtonLabel(username, CSS.white, true);
		this.signInMenu.setImage(onImage, offImage);
	}

	public function setSaveStatus(text:String, isAlert:Boolean, context:Dictionary):void {
		if (text == this.saveStatus.text) {
			return;
		}

		this.saveStatus.text = Translator.map(text, context);
		this.saveStatus.setTextFormat(isAlert ? this.saveStatusAlertFormat : this.saveStatusFormat);
		this.saveStatus.alpha = isAlert ? 1 : 0.6;
		this.fixStatusLayout();
	}

	private function fixStatusLayout():void {
		this.saveStatus.x = this.myStuffButton.x - this.saveStatus.textWidth - 15;
		this.saveStatus.y = 6;
	}

	private function addSaveStatus():void {
		addChild(this.saveStatus = makeLabel("", this.saveStatusFormat));
		this.saveStatus.addEventListener(MouseEvent.MOUSE_DOWN, ScratchOnline.app.saveStatusClicked);
	}

	public function showTransitionNotice(text:String):void {
		this.hideTransitionNotice();
		this.transitionNotice = new Sprite();

		var x:int = app.stage.stageWidth - app.tabsRight() - 11;
		var g:Graphics = this.transitionNotice.graphics;

		g.beginFill(16302972);
		g.drawRect(0, 0, x, 22);
		g.endFill();

		var label:TextField = makeLabel(Translator.map(text), CSS.topBarButtonFormat, 3, 2);
		this.transitionNotice.addChild(label);
		this.transitionNotice.x = w - x - 5;
		this.transitionNotice.y = h + 5;
		addChild(this.transitionNotice);
	}

	public function hideTransitionNotice():void {
		if (this.transitionNotice) {
			removeChild(this.transitionNotice);
			this.transitionNotice = null;
		}
	}
}
}
