package table ;
import externs.Tippy;
import externs.TippyOptions;
import haxe.DynamicAccess;
import js.html.Element;
import js.html.InputElement;
import js.html.TableCellElement;
import js.html.TableRowElement;
import js.html.URLSearchParams;
import js.lib.Object;
import table.FancyColumn;
import table.FancyTableEditor;
import table.FancyRow;
import table.LinkListColumn;
import type.IntRange;
import type.Keyboard;
using tools.HtmlTools;
import js.Browser.*;

/**
 * ...
 * @author YellowAfterlife
 */
class FancyTable<KB:Keyboard> {
	public var columns:Array<FancyColumn<KB>> = [];
	public var filterOrder:Array<FancyTableFilterOrder<KB>> = [];
	public var keyboards:Array<KB> = [];
	public var header:FancyRow<KB> = null;
	public var rows:Array<FancyRow<KB>> = [];
	public var countElement:Element = null;
	public var testRow:FancyRow<KB> = null;
	public var outElement:Element = null;
	
	public function new() {
		
	}
	public function addColumn(col:FancyColumn<KB>) {
		col.table = this;
		columns.push(col);
		filterOrder.push(Column(col));
	}
	
	public function resolveParent(kb:KB) {
		var parentName = kb.parent;
		if (parentName == null) return;
		kb.parent = null;
		
		var parent = keyboards.filter(ikb -> ikb.name == parentName)[0];
		if (parent == null) {
			console.error('Unknown parent "$parentName" in "${kb.name}"');
			return;
		}
		resolveParent(parent);
		
		// don't copy link lists to children:
		var tmp = Reflect.copy(parent);
		for (col in columns) if (col is LinkListColumn) {
			(cast col:LinkListColumn<KB>).field.access(tmp, true, null);
		}
		
		for (key in Object.keys(tmp)) {
			var val = Reflect.field(tmp, key);
			if (val == null) continue;
			if (Reflect.field(kb, key) != null) continue;
			Reflect.setField(kb, key, val);
		}
	}
	public function resolveParents() {
		for (kb in keyboards) resolveParent(kb);
	}
	
	public function addFilterHeader(text:String) {
		var h = new FancyFilterHeader(text);
		filterOrder.push(Header(h));
		return h;
	}
	public function buildFilters(out:Element) {
		FancyTableFilters.build(this, out);
	}
	
	public function sortBy(sortColumn:FancyColumn<KB>, ascending:Bool) {
		var sortRows = rows.copy();
		sortRows.sort(function(a, b) {
			return sortColumn.compareKeyboards(a.keyboard, b.keyboard, ascending);
		});
		sortRows.reverse();
		for (row in sortRows) header.element.after(row.element);
	}
	public var sortColHead:FancyTableHeaderCell<KB> = null;
	public var sortAscending:Bool = false;
	public function createRow(keyboard:KB) {
		var row = new FancyRow(keyboard);
		for (column in columns) {
			var cell = new FancyTableCell(column);
			cell.element.setDisplayFlag(column.show);
			column.buildValue(cell.element, keyboard);
			row.cells.push(cell);
			row.element.appendChild(cell.element);
		}
		return row;
	}
	public function buildTable(out:Element) {
		outElement = out;
		header = new FancyRow(null);
		for (column in columns) {
			var cell = new FancyTableHeaderCell(column);
			cell.element.setDisplayFlag(column.show);
			cell.element.id = "header-" + column.getId();
			if (column.shortName != null) {
				cell.element.appendTextNode(column.shortName);
				cell.element.title = column.name;
			} else {
				cell.element.appendTextNode(column.name);
			}
			if (column.canSort) {
				cell.element.classList.add("can-sort");
				var sfx = "Can sort";
				if (cell.element.title != null) {
					cell.element.title += "\n" + sfx;
				} else cell.element.title = sfx;
				cell.element.onclick = function(_) {
					if (sortColHead != cell) {
						if (sortColHead != null) {
							sortColHead.element.classList.remove("sort-column");
							sortColHead.element.classList.remove("sort-ascending");
						}
						sortAscending = false;
						sortColHead = cell;
						sortColHead.element.classList.add("sort-column");
					} else {
						sortAscending = !sortAscending;
						sortColHead.element.classList.setTokenFlag("sort-ascending", sortAscending);
					}
					sortBy(sortColHead.column, sortAscending);
					updateURL();
				}
			}
			header.cells.push(cell);
			header.element.appendChild(cell.element);
		}
		out.appendChild(header.element);
		//
		for (keyboard in keyboards) {
			var row = createRow(keyboard);
			rows.push(row);
			out.appendChild(row.element);
		}
		if (countElement != null) countElement.innerText = "" + keyboards.length;
	}
	public var canUpdateFilters:Bool = false;
	public function updateFilters(_updateURL:Bool = true) {
		if (!canUpdateFilters) return;
		var found = 0;
		for (row in rows) {
			var keyboard = row.keyboard;
			var show = true;
			for (column in columns) if (column.wantFilter) {
				if (column.matchesFilter(keyboard)) continue;
				show = false;
				break;
			}
			row.element.setDisplayFlag(show);
			if (show) found++;
		}
		if (countElement != null) countElement.innerText = "" + found;
		
		//
		if (_updateURL) updateURL();
	}
	
	/** -> "shape=Split&kit" */
	public function saveFilters():String {
		var params = new DynamicAccess();
		for (column in columns) if (column.wantFilter) {
			column.saveFilterParams(params);
		}
		if (sortColHead != null) {
			var id = sortColHead.column.getId();
			if (!sortAscending) id = "-" + id;
			params["sort"] = id;
		}
		
		var paramKeys = params.keys();
		if (paramKeys.length == 0) return "";
		
		var paramPairs = [];
		for (key in paramKeys) {
			var val = params[key];
			if (val != "") {
				val = (cast window).encodeURIComponent(params[key]);
				paramPairs.push(key + "=" + val);
			} else paramPairs.push(key);
		}
		if (paramPairs.length == 0) return "";
		return "?" + paramPairs.join("&");
	}
	
	public var canUpdateURL = true;
	public var baseURL:String = "https://yal-tools.github.io/ergo-keyboards/";
	public function updateURL() {
		if (!canUpdateURL) return;
		var search = saveFilters();
		var loc = document.location;
		var prefix = Main.baseURL;
		if (loc.protocol == "file:") {
			prefix = "https://yal-tools.github.io/ergo-keyboards/";
		} else {
			prefix = loc.origin + loc.pathname;
		}
		var url = prefix + search + loc.hash;
		
		try {
			window.history.replaceState("", "", url);
			return;
		} catch (x:Dynamic) {}
		
		var fd:InputElement = document.querySelectorAuto("#share-field");
		fd.style.display = "inherit";
		fd.value = url;
	}
	public function loadFilters(search:String) {
		var params = new URLSearchParams(search);
		var obj = new DynamicAccess<String>();
		params.forEach(function(val, key, _) {
			obj[key] = val;
		});
		
		canUpdateFilters = false;
		var wantFilter = false;
		for (column in columns) {
			var filter = column.loadFilterParams(obj);
			column.filterCheckbox.checked = filter;
			if (filter) {
				column.filterCheckbox.onchange(null);
				wantFilter = true;
			}
		}
		canUpdateFilters = true;
		
		var sort = obj["sort"];
		if (sort != null) {
			var desc = sort.charAt(0) == "-";
			if (desc) sort = sort.substr(1);
			var th = document.getElementById("header-" + sort);
			if (th != null) {
				th.click();
				if (!desc) th.click();
			}
		}
		
		if (wantFilter) updateFilters(false);
	}
	public function loadTest(kb:KB) {
		if (testRow != null) {
			testRow.element.parentElement.removeChild(testRow.element);
			keyboards.remove(testRow.keyboard);
		}
		for (col in columns) col.load(kb);
		testRow = createRow(kb);
		outElement.appendChild(testRow.element);
		rows.push(testRow);
	}
}
enum FancyTableFilterOrder<KB:Keyboard> {
	Column(col:FancyColumn<KB>);
	Header(h:FancyFilterHeader);
}
class FancyFilterHeader {
	public var text:String;
	public var filterNotes:Array<FancyHeaderNote> = [];
	public var editorNotes:Array<FancyHeaderNote> = [];
	public function new(text:String) {
		this.text = text;
	}
}
class FancyHeaderNote {
	public var text:String;
	public var func:Element->Void;
	public function new(text:String, ?func:Element->Void) {
		this.text = text;
		this.func = func;
	}
}