function displayTile (name)
{
	$("<div/>", {
		id: "tile-"+name,
		class: "tile",
		text: name,
		click: function(){ switchTile(this.id) }
	}).appendTo($("#tilepane"));
}

function displayColumn (name, type) 
{
	var $li = $("#column-template").clone().removeAttr("id");
	$(".column-name", $li).text(name.replace(/_/, " "));
	$(".column-type", $li).text("("+type+")");
	$li.addClass("column");
		$li.hover(function(){
		$("img", this).toggle();
	});
	$("img", $li).hide();
	$("img", $li).click(function(){
		if(confirm("Are you sure? who knows what will happen if you remove a column.."))
		{
			var column_name = $(".column-name", $(this).parent()).text();
			var column_type = $(".column-type", $(this).parent()).text();

			$(this).parent().fadeOut();
			// TODO: make this more robust than this fire-and-forget ;-)
			$.post("/framework/columns/remove", {	
					model: $(".tile-selected").html(), 
					column: column_name, 
					column_type: column_type
			});
			if($("#columns .column").length == 0) $("#columns-empty").show();
		}
	});
	
	$("#columns").append($li).fadeIn();
}

function displayAssociation (type, target)
{
	var $li = $("#association-template").clone().removeAttr("id");
	$(".association-type", $li).text(type);
	$(".association-target", $li).text(target);
	$li.addClass("association");
		$li.hover(function(){
		$("img", this).toggle();
	});
	$("img", $li).hide();
	$("img", $li).click(function(){
		if(confirm("Are you sure? who knows what will happen if you remove an association.."))
		{
			var assoc_type = $(".association-type", $(this).parent()).text();
			var assoc_target = $(".association-target", $(this).parent()).text();

			$(this).parent().fadeOut();
			// TODO: make this more robust than this fire-and-forget ;-)
			$.post("/framework/associations/remove", {	
					model: $(".tile-selected").html(), 
					association_target: assoc_target, 
					association_type: assoc_type
			});
			if($("#associations .association").length == 0) $("#association-empty").show();
		}
	});
	
	$("#associations").append($li).fadeIn();		
}

function displayModel (model)
{
	// remove the columns & associations from the previous model
	$("#columns .column").remove();
	$("#associations .association").remove();
	
	// get the columns
	$.getJSON('/framework/columns/'+model, function(data){
		$.each(data, function(index,value){
			displayColumn(value.name, value.type);
		});
		if($("#columns .column").length == 0) $("#columns-empty").show();	
	});
	
	// get the associations
	$.getJSON('/framework/associations/'+model, function(data){
		$.each(data, function(index,value){
			displayAssociation(value.macro, value.name);
		});	
		if($("#associations .association").length == 0) $("#associations-empty").show();			
	});
}

function hideColumnForm() 
{
	$("#column-new").hide();
	$("#column-new-form")[0].reset();
	$("#column-new-link").show();		
}

function hideAssociationForm() 
{
	$("#association-new").hide();
	$("#association-new-form")[0].reset();
	$("#association-new-link").show();			
}

function switchTile(tileID)
{		
	if($("#tilepane .tile").length == 0)
	{
		// empty tile pane
		$("#tile-empty").show();
		$("#model-editor").hide();
	}
	else
	{
		// can be called without a param to reset to the first one eg. on a delete
		if (tileID == null) tileID = $("#tilepane .tile").first().attr("id");
		
		$(".tile-selected").removeClass("tile-selected");
		$("#"+tileID).addClass("tile-selected");
		
		// setup the model view / edit
		var model = $("#"+tileID).html(); // tile names are model names
		displayModel(model);
		hideColumnForm();
		$('#column-new-form input[name="model"]').val(model);
		
		hideAssociationForm();
		$('#association-new-form input[name="model"]').val(model);
		$("#association-new-form select[name='association_target'] option").remove();
		$.each($("#tilepane .tile"), function(){
			$("<option/>", {
				text: $(this).text(),
			}).appendTo($("#association-new-form select[name='association_target']"));
		});
		$("#model-editor").show();
	}
}

$(document).ready(function()
{
	// get the models
	$.getJSON('/framework/models', function(data){
		if(data.length > 0)
		{
			$.each(data, function(index,value){
				displayTile(value);
			});
			// switch to the first one
			switchTile($("#tilepane .tile").first().attr("id"));
			$("#tile-empty").hide();
			$("#model-editor").show();
		} 
		else
		{
			$("#model-editor").hide();
		} 
	});
	
	// new model experience
	$("#tile-new").hide();
	$("#tile-new-link").click(function(){ 
		$("#new-model-form")[0].reset();
		$("#tile-new").show();
		$("#new-model-form input[name='model']").focus();
		$("#tile-empty").hide();
		$("#tile-new-link").hide();
	});
	
	$("#new-model-form")
		.bind("ajax:beforeSend", function(){
			displayTile($("#new-model-form input[name='model']").val());
			$("#tile-new").hide();
			$("#model-waiting").show();
		})
		.bind("ajax:success", function(evt, data, status, xhr){
			switchTile("tile-"+xhr.responseText);
			$("#model-waiting").hide();
			$("#tile-new-link").show();
		})
		.bind("ajax:error", function(evt, data, status, xhr){
			// TODO: when model create fails
		});
	$("#model-waiting").hide();
	
	// remove model button
	$("#model-remove").click(function(){
		if(confirm("Are you sure? This will remove the model and any data."))
		{
			var to_remove = $(".tile-selected");
			$.post('/framework/models/remove', { model: to_remove.html()}, 
				function(){
					to_remove.remove();
					switchTile();
				});
		}
	});
	
	// new column experience
	$("#column-new").hide();
	$("#column-new-link").click(function(){
		$("#column-new").show();
		$("#column-new-link").hide();
		$('#column-new-form input[name="column_name"]').focus();
	});
	$("#column-new-cancel").click(function(){ hideColumnForm() });
	
	$("#column-new-form")
		.bind("ajax:beforeSend", function(){
			var column_name = $("input[name='column_name']").val();
			column_name = column_name.replace(/ /, "_");
			if(column_name == "")
			{
				alert("Columns have to have names.. idiot!");
				return false;
			}
			$("input[name='column_name']").val(column_name);

			displayColumn(column_name, $("select[name='column_type']").val());
			$("#columns-empty").hide();
			$("#column-new-form")[0].reset();
			$("input[name='column_name']", this).focus();
		})
		.bind("ajax:success", function(evt, data, status, xhr){
			// TODO: do something when column create succeeds.. or not?
		})
		.bind("ajax:error", function(evt, data, status, xhr){
			// TODO: handle when column create fails
			alert("There was a problem creating the column.. it was probably your fault.");
		});
	$("#columns-empty").hide();
		
	// new association experience
	$("#association-new").hide();
	$("#association-new-link").click(function(){
		$("#association-new").show();
		$("#association-new-link").hide();
		$('#association-new-form input[name="association_name"]').focus();
	});
	$("#association-new-cancel").click(function(){ hideAssociationForm() });
	
	$("#association-new-form")
		.bind("ajax:beforeSend", function(){
			// TODO: check for association names that exist already.. have illegal chars etc
			// can return false to cancel the request
			displayAssociation($("select[name='association_type']").val(), $("select[name='association_target']").val());
			$("#associations-empty").hide();
			$("#association-new-form")[0].reset();
			$("input[name='association_type']", this).focus();
		})
		.bind("ajax:success", function(evt, data, status, xhr){
			// TODO: do something when association create succeeds.. or not?
		})
		.bind("ajax:error", function(evt, data, status, xhr){
			// TODO: handle when association create fails
			alert("There was a problem creating the association.. it was probably your fault.");
		});
	$("#associations-empty").hide();
});