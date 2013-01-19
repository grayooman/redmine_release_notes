require File.dirname(__FILE__) + '/../test_helper'

class IssueHookTest < ActionController::TestCase
  def setup
    @controller = IssuesController.new

    # this is rather horrible; there should be a better way
    Setting.clear_cache

    @user = User.anonymous

    # set up release notes
    @cf         = FactoryGirl.create(:release_notes_custom_field)
    @settings   = FactoryGirl.create(:release_notes_settings,
                                     :issue_required_field_id => @cf.id)
    @tracker    = FactoryGirl.create(:tracker,
                                     :custom_fields => [@cf])
    @project    = FactoryGirl.create(:project,
                                    :trackers => [@tracker],
                                    :enabled_module_names =>
                                      %w(issue_tracking release_notes))
    @issue      = FactoryGirl.create(:issue,
                                     :project => @project,
                                     :tracker => @tracker)
    @issue.create_release_note!(:text => "product can now do backflips")

    # allow anonymous user to view issues in this project
    @role       = @user.roles_for_project(@project).first
    @role.permissions = [:view_issues]
    @role.save!
  end

  def assert_release_notes_displayed
    assert_response :success
    assert_select 'div.flash.error', false
    assert_select 'div#release_notes>p',
      :text => /product can now do backflips/
  end

  def assert_release_notes_not_displayed
    assert_response :success
    assert_select 'div.flash.error', false
    assert_select 'div#release_notes>p', false
  end

  test 'release notes displayed when custom field is for all projects' do
    @cf.is_for_all = true
    @cf.save!

    get :show, :id => @issue.id

    assert_release_notes_displayed
  end

  test 'release notes displayed when custom field is not for all projects' do
    @cf.is_for_all = false
    @cf.save!
    @project.issue_custom_fields = [@cf]
    @project.save!

    get :show, :id => @issue.id

    assert_release_notes_displayed
  end

  test 'release notes not displayed if module not enabled for the project' do
    @project.enabled_modules.where('name = ?', 'release_notes').destroy_all
    @project.save!

    get :show, :id => @issue.id

    assert_release_notes_not_displayed
  end

  test 'release notes not displayed if project does not have release notes' +
    ' custom field enabled' do
    @project.issue_custom_fields.delete(@cf)

    get :show, :id => @issue.id

    assert_release_notes_not_displayed
  end

  test "release notes not displayed if issue's tracker does not have the" +
    " release notes custom field" do
    tracker = @project.trackers.first
    tracker.custom_fields.delete(@cf)

    get :show, :id => @issue.id

    assert_release_notes_not_displayed
  end

  test 'error is shown on issues#show when issue custom field is not set up' do
    @settings.value = @settings.value.
      update('issue_required_field_id' => 'garbage')
    @settings.save!

    get :show, :id => @issue.id

    assert_response :success
    assert_select 'div.flash.error',
      :text => I18n.t(:failed_find_issue_custom_field)
  end

  test 'configure link is only shown on when issue custom field is not set up' +
    ' and current user is admin' do
    @settings.value = @settings.value.
      update('issue_required_field_id' => 'garbage')
    @settings.save!

    get :show, :id => @issue.id

    assert_response :success
    assert_select 'div.flash.error',
      :text => I18n.t(:failed_find_issue_custom_field)

    @admin = FactoryGirl.create(:user, :admin => true)
    @request.session[:user_id] = @admin.id

    get :show, :id => @issue.id

    assert_response :success
    assert_select 'div.flash.error',
      :text => /#{I18n.t(:button_configure)}/
  end
end
