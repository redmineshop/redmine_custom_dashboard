# frozen_string_literal: true

# Period whitelist and in-progress label rules. No Redmine boot.
require 'minitest/autorun'

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)
require 'redmine_custom_dashboard/dashboard_stats'

class DashboardStatsStandaloneTest < Minitest::Test
  Stats = RedmineCustomDashboard::DashboardStats

  def test_period_whitelist
    assert_equal '7', Stats.normalize_period('7')
    assert_equal '30', Stats.normalize_period('30')
    assert_equal '90', Stats.normalize_period('90')
    assert_equal '90', Stats.normalize_period(' 90 ')
    assert_equal '7', Stats.normalize_period(7)
  end

  def test_period_rejects_non_whitelist
    assert_equal '30', Stats.normalize_period(nil)
    assert_equal '30', Stats.normalize_period('')
    assert_equal '30', Stats.normalize_period('14')
    assert_equal '30', Stats.normalize_period('90days')
    assert_equal '30', Stats.normalize_period("7' OR '1'='1")
    assert_equal '30', Stats.normalize_period(['90'])
    assert_equal '30', Stats.normalize_period({ 'period' => '7' })
  end

  def test_in_progress_labels_keep_english_and_vietnamese
    labels = Stats.in_progress_labels
    assert_includes labels, 'in progress'
    assert_includes labels, 'đang thực hiện'
  end

  def test_in_progress_label_matching
    labels = Stats.in_progress_labels(['En cours'])
    assert Stats.in_progress_label?('In Progress', labels)
    assert Stats.in_progress_label?('  in progress  ', labels)
    assert Stats.in_progress_label?('Đang thực hiện', labels)
    assert Stats.in_progress_label?('ĐANG THỰC HIỆN', labels)
    assert Stats.in_progress_label?('En cours', labels)
    refute Stats.in_progress_label?('Feedback', labels)
    refute Stats.in_progress_label?('Custom WIP', labels)
    refute Stats.in_progress_label?('', labels)
    refute Stats.in_progress_label?(nil, labels)
  end
end
