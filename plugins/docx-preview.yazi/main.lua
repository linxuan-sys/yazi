-- docx.yazi plugin - Preview docx files using pandoc
local M = {}

local function get_file_path(file)
	return tostring(file.path or file.cache or file.url.path or file.url)
end

function M:peek(job)
	local file_path = get_file_path(job.file)
	
	-- Run pandoc to extract text
	local output, err = Command("pandoc")
		:arg({ "-t", "plain", "--wrap=auto", "--columns=100", file_path })
		:output()
	
	if err then
		ya.preview_widget(
			job,
			ui.Text({
				ui.Line({ ui.Span("Docx Preview Error"):style(ui.Style():fg("red"):bold()) }),
				ui.Line({}),
				ui.Line({ ui.Span("pandoc command failed: " .. tostring(err)):style(ui.Style():fg("yellow")) }),
				ui.Line({ ui.Span("File: " .. file_path):style(ui.Style():fg("blue")) }),
			}):area(job.area):wrap(ui.Wrap.YES)
		)
		return
	end

	if not output or not output.status.success then
		local stderr = output and output.stderr or "no output"
		ya.preview_widget(
			job,
			ui.Text({
				ui.Line({ ui.Span("Docx Preview Error"):style(ui.Style():fg("red"):bold()) }),
				ui.Line({}),
				ui.Line({ ui.Span("pandoc exited with error:"):style(ui.Style():fg("yellow")) }),
				ui.Line({ ui.Span(stderr):style(ui.Style():fg("blue")) }),
			}):area(job.area):wrap(ui.Wrap.YES)
		)
		return
	end

	local text = output.stdout or ""
	if text == "" then
		ya.preview_widget(
			job,
			ui.Text({
				ui.Line({ ui.Span("No text content found"):style(ui.Style():fg("yellow")) }),
			}):area(job.area)
		)
		return
	end

	-- Split text into lines
	local lines = {}
	for line in text:gmatch("[^\r\n]+") do
		table.insert(lines, ui.Line({ ui.Span(line) }))
	end

	-- Handle pagination
	local skip = job.skip or 0
	local limit = job.area.h
	local start_idx = skip + 1
	local end_idx = math.min(start_idx + limit - 1, #lines)

	-- Extract current page lines
	local page_lines = {}
	for i = start_idx, end_idx do
		table.insert(page_lines, lines[i])
	end

	-- Display content
	ya.preview_widget(job, ui.Text(page_lines):area(job.area):wrap(ui.Wrap.YES))
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		ya.emit("peek", {
			math.max(0, cx.active.preview.skip + job.units),
			only_if = job.file.url,
		})
	end
end

return M
