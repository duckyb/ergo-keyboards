package;

import externs.Tippy;
import externs.TippyOptions;
import js.Lib;
import ColStagTable;
import js.html.DetailsElement;
import js.html.Element;
import js.html.InputElement;
import table.FancyTableShuffler;
import table.*;
using tools.HtmlTools;
import js.Browser.*;
import type.Keyboard;

/**
 * ...
 * @author YellowAfterlife
 */
class Main {
	public static var baseURL:String = "https://yal-tools.github.io/ergo-keyboards/";
	static function main() {
		LinkListColumn.domainCountries = (cast window).domainCountries;
		LinkListColumn.countryTags = (cast window).countryTags;
		ToDoList.element = document.querySelectorAuto("#todo");
		//
		var divFilters:Element = document.querySelectorAuto("#filter");
		var kbTable:KeyboardTable<Keyboard>;
		if (document.body.classList.contains("rowstag")) {
			kbTable = cast new RowStagTable();
		} else kbTable = cast new ColStagTable();
		kbTable.resolveParents();
		kbTable.countElement = document.querySelectorAuto("#count");
		kbTable.buildFilters(divFilters);
		kbTable.buildTable(document.querySelectorAuto("#data"));
		FancyTableEditor.build(kbTable,
			document.querySelectorAuto("#editor"),
			document.querySelectorAuto("#editor-load"),
			document.querySelectorAuto("#editor-reset"),
			document.querySelectorAuto("#editor-build"),
			document.querySelectorAuto("#editor-test"),
			document.querySelectorAuto("#editor-output")
		);
		//
		var loc = document.location;
		if (loc.protocol != "file:") {
			kbTable.baseURL = loc.origin + loc.pathname;
		}
		
		//
		var btClearFilters:InputElement = document.querySelectorAuto("#clear-filters");
		btClearFilters.onclick = function() {
			FancyTableControls.clearFilters(kbTable, divFilters);
		}
		
		//
		var cbAutoUpdateURL:InputElement = document.querySelectorAuto("#auto-update-url");
		kbTable.canUpdateURL = cbAutoUpdateURL.checked;
		cbAutoUpdateURL.addEventListener("change", function(_) {
			kbTable.canUpdateURL = cbAutoUpdateURL.checked;
		});
		
		//
		var btShare:InputElement = document.querySelectorAuto("#copy-share-url");
		FancyTableControls.createShareButton(kbTable, btShare);
		
		//
		var shuffler = new FancyTableShuffler<Keyboard>("");
		if (location.hostname == "localhost") {
			var editorDetails:DetailsElement = document.querySelectorAuto("#editor-outer");
			editorDetails.open = true;
		} else {
			kbTable.sortBy(shuffler, false);
		}
		document.querySelectorAuto("#shuffle", InputElement).onclick = function() {
			if (kbTable.sortColHead != null) {
				kbTable.sortColHead.element.classList.remove("sort-column");
				kbTable.sortColHead.element.classList.remove("sort-ascending");
				kbTable.sortColHead = null;
			}
			kbTable.sortBy(shuffler, false);
			kbTable.updateURL();
		}
		//
		document.querySelectorAuto("#copy-md", InputElement).onclick = function() {
			var md = FancyTableToMD.run(kbTable);
			navigator.clipboard.writeText(md);
		}
		//
		kbTable.loadFilters(document.location.search);
		console.log("Hello!");
	}
	
}