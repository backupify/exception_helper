guard(:minitest, :all_after_pass => false, :all_on_start => false) do
  watch(%r{^lib/exception_helper/(.+)\.rb$})                               { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test/.+_test\.rb$})
  watch(%r{^(lib/exception_helper|test/test_helper)\.rb$}) { 'test' }
end
