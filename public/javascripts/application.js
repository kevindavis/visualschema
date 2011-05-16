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
	$(".column-name", $li).text(name);
	$(".column-type", $li).text(" ("+type+")");
	$($li).addClass("column");
	$($li).hover(function(){
		$("img", this).toggle();
	});
	$("img", $li).hide();
	$("img", $li).click(function(){
		if(confirm("Are you sure? who knows what will happen if you remove a column.."))
		{
			var to_remove = $(".column-name", $(this).parent()).text();
			$(this).parent().fadeOut();
			$.post("/framework/columns/remove", {model: $(".tile-selected").html(), column: to_remove});
			// TODO: make this more robust than this fire-and-forget ;-)
		}
	});
	
	$li.appendTo($("#columns"));
}

function displayAssociation (name, type)
{
	$("<li/>", {
		text: name + " (" + type + ")"
	}).appendTo($("#associations"));		
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
	});
	
	// get the associations
	$.getJSON('/framework/associations/'+model, function(data){
		$.each(data, function(index,value){
			displayAssociation(value.name, value.type);
		});			
	});		
}

function hideColumnForm() 
{
	$("#column-new").hide();
	$("#column-new-form")[0].reset();
	$("#column-new-link").show();		
}

function switchTile(tileID)
{		
	if($("#tilepane .tile").length == 0)
	{
		$("#tile-empty").show();
		$("#model-editor").hide();
	}
	else
	{
		$(".tile-selected").removeClass("tile-selected");
		$("#"+tileID).addClass("tile-selected");

		var model = $("#"+tileID).html(); // tile names are model names
		displayModel(model);
		hideColumnForm();
		$('#column-new-form input[name="model"]').val(model);
		$("#model-editor").show();
	}
}

function setup()
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
		$('#new-model-form input[name="model"]').focus();
		$("#tile-new").show();
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
		.bind("ajax:success", function(evt, data, status, xhr){
			displayColumn(data.name,data.type);
			$("#column-new-form")[0].reset();
		})
		.bind("ajax:error", function(evt, data, status, xhr){
			// TODO: when column create fails
		});
	
}
		
$(document).ready(function() {
  setup();
});