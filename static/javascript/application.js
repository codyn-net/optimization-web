String.prototype.endsWith = function(suffix) {
	return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

function select_header()
{
	var pname = document.location.pathname;

	$('#menubar a').each(function (i, a) {
		a = $(a);

		var href = a.attr('href');

		if (pname.endsWith(href) || (href == 'index.html' && !pname.endsWith('.html')))
		{
			a.addClass('selected');
		}
	});
}

$(document).ready(function () {
	select_header();
});
