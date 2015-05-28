require 'redmine'

Redmine::WikiFormatting::Macros.register do
	desc "List task by project version."
	macro :list_task do |obj, args|
		args, options = extract_macro_options(args, :version, :category)

		version_id = options[:version]
		category_id = options[:category]

		tasks = Issue.where("category_id = ? AND fixed_version_id = ?", category_id, version_id)

		out = ''.html_safe
		task_list = ''.html_safe
		tasks.each do |task|
			item = format_task(task.id)
			task_list << content_tag('li', item)
		end
		out << content_tag('ol', task_list)

		summary = format_summary(tasks)
		out << content_tag('p', summary)
	end
end

Redmine::WikiFormatting::Macros.register do
	desc "Show task by id."
	macro :show_task do |obj, args|
		format_task(args.first)
	end
end

def format_task(task_id)
	#if responsible_user is nil
	default_responsible_user = "N/A"

	task = Issue.find(task_id)

	subject = task.subject.tr(%q{"}, '\'')
	subject_info = "\"#{subject}\":/issues/#{task.id}"
	responsible_user = get_responsible_user(task_id) || default_responsible_user

	spent_hours = accum_spent_hours(task.id).round(1)
	time_info = format_time_block(spent_hours, task.estimated_hours)

	clear_textile("#{task.status}. ##{task.id}. #{subject_info}. #{responsible_user} #{time_info}")
end

def format_summary(tasks)
	spent_hours = 0
	estimated_hours = 0

	tasks.each do |task|
		spent_hours += accum_spent_hours(task.id).round(1)
		estimated_hours += task.estimated_hours.nil? ? 0 : task.estimated_hours.round(1)
	end

	time_info = format_time_block(spent_hours, estimated_hours)

	clear_textile("Итого: #{time_info}")
end

def get_responsible_user(task_id)
	custom_field_type = "Issue"
	responsible_custom_field_id = 5

	User.joins('LEFT JOIN custom_values ON users.id = custom_values.value') \
	    .where("custom_values.customized_type = ? AND custom_values.custom_field_id = ? AND custom_values.customized_id = ?", custom_field_type, responsible_custom_field_id, task_id) \
	    .first
end

def format_time_block(spent_hours, estimated_hours)
	#if estimated_hours is nil
	default_estimated_hours = "N/A"

	if estimated_hours.nil?
		time_color = ""
	elsif spent_hours > estimated_hours
		time_color = "#EDD3D3"
	else
		time_color = "#D3EDD3"
	end

	estimated_hours = estimated_hours.nil? ? default_estimated_hours : estimated_hours.round(1)

	"%{background:#{time_color}}(#{estimated_hours} / #{spent_hours})%"
end

def clear_textile(text)
	textilizable(text).gsub(/^<p>|<\/p>$/, '').html_safe
end

def accum_spent_hours(task_id)
	task = Issue.find(task_id)

	spent_hours = task.spent_hours

	childs = Issue.where("parent_id = ?", task_id)

	childs.each do |child|
		child_spent_hours = accum_spent_hours(child.id)
		spent_hours += child_spent_hours
	end

	spent_hours
end