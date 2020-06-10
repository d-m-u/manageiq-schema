require_migration

describe AddAncestryToVm do
  let(:rel_stub) { migration_stub(:Relationship) }
  let(:vm_stub) { migration_stub :VmOrTemplate }
  let(:vm) { vm_stub.create! }
  let(:vm2) { vm_stub.create! }
  let(:vm3) { vm_stub.create! }
  let(:vm4) { vm_stub.create! }
  let(:vm5) { vm_stub.create! }
  let(:vm6) { vm_stub.create! }
  let(:root) { vm_stub.create! }
  let(:vm7) { vm_stub.create! }
  let(:vm8) { vm_stub.create! }

  migration_context :up do
    context "single parent/child rel" do
      it 'updates ancestry' do
        parent_rel = rel_stub.create!(:relationship => 'genealogy', :ancestry => nil, :resource_type => 'VmOrTemplate', :resource_id => root.id)
        rel_stub.create!(:relationship => 'genealogy', :ancestry => parent_rel.id, :resource_type => 'VmOrTemplate', :resource_id => vm.id)

        migrate

        expect(vm.reload.ancestry).to eq(root.id.to_s)
        expect(root.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(0)
      end
    end

    context "slightly more complicated tree" do
      it 'updates ancestry' do
        parent_rel = rel_stub.create!(:relationship => 'genealogy', :ancestry => nil, :resource_type => 'VmOrTemplate', :resource_id => root.id)
        child_rel = rel_stub.create!(:relationship => 'genealogy', :ancestry => parent_rel.id, :resource_type => 'VmOrTemplate', :resource_id => vm.id)
        rel_stub.create!(:relationship => 'genealogy', :ancestry => child_rel.id.to_s + '/' + parent_rel.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm2.id)

        migrate

        expect(vm.reload.ancestry).to eq(root.id.to_s)
        expect(vm2.reload.ancestry).to eq("#{vm.id}/#{root.id}")
        expect(root.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(0)
      end
    end

    context "complicated tree" do
      #           a
      #      b         c
      #      d         g
      #    e   f
      it 'updates ancestry' do
        rel_a = rel_stub.create!(:relationship => 'genealogy', :ancestry => nil, :resource_type => 'VmOrTemplate', :resource_id => root.id)
        rel_c = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_a.id, :resource_type => 'VmOrTemplate', :resource_id => vm.id)
        rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_c.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm2.id)
        rel_b = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm3.id)
        rel_d = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm4.id)
        rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_d.id.to_s + '/' + rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm5.id)
        rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_d.id.to_s + '/' + rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm6.id)

        migrate

        expect(vm5.reload.ancestry).to eq("#{vm4.id}/#{vm3.id}/#{root.id}")
        expect(vm6.reload.ancestry).to eq("#{vm4.id}/#{vm3.id}/#{root.id}")
        expect(vm3.reload.ancestry).to eq(root.id.to_s)
        expect(vm.reload.ancestry).to eq(root.id.to_s)
        expect(vm2.reload.ancestry).to eq("#{vm.id}/#{root.id}")
        expect(root.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(0)
      end
    end

    context "order is preserved" do
      #      rel vm
      #      a   root
      #      b   3
      #      d   4
      #      e   6
      #      c   vm
      #      f   2
      #      g   7
      #      h   8
      it 'updates ancestry' do
        rel_a = rel_stub.create!(:relationship => 'genealogy', :ancestry => nil, :resource_type => 'VmOrTemplate', :resource_id => root.id)
        rel_b = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm3.id)
        rel_d = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm4.id)
        rel_e = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_d.id.to_s + '/' + rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm6.id)
        rel_c = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_e.id.to_s + '/' + rel_d.id.to_s + '/' + rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm.id)
        rel_f = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_c.id.to_s + '/' + rel_e.id.to_s + '/' + rel_d.id.to_s + '/' + rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm2.id)
        rel_g = rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_f.id.to_s + '/' + rel_c.id.to_s + '/' + rel_e.id.to_s + '/' + rel_d.id.to_s + '/' + rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm7.id)
        rel_stub.create!(:relationship => 'genealogy', :ancestry => rel_g.id.to_s + '/' + rel_f.id.to_s + '/' + rel_c.id.to_s + '/' + rel_e.id.to_s + '/' + rel_d.id.to_s + '/' + rel_b.id.to_s + '/' + rel_a.id.to_s, :resource_type => 'VmOrTemplate', :resource_id => vm8.id)

        migrate

        expect(vm2.reload.ancestry).to eq("#{vm.id}/#{vm6.id}/#{vm4.id}/#{vm3.id}/#{root.id}")
        expect(vm6.reload.ancestry).to eq("#{vm4.id}/#{vm3.id}/#{root.id}")
        expect(vm3.reload.ancestry).to eq(root.id.to_s)
        expect(vm.reload.ancestry).to eq("#{vm6.id}/#{vm4.id}/#{vm3.id}/#{root.id}")
        expect(vm7.reload.ancestry).to eq("#{vm2.id}/#{vm.id}/#{vm6.id}/#{vm4.id}/#{vm3.id}/#{root.id}")
        expect(vm8.reload.ancestry).to eq("#{vm7.id}/#{vm2.id}/#{vm.id}/#{vm6.id}/#{vm4.id}/#{vm3.id}/#{root.id}")
        expect(root.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(0)
      end
    end

    context "vm without rels" do
      it 'nil ancestry' do
        migrate

        expect(vm_stub.find(vm.id).ancestry).to eq(nil)
      end
    end

    context "with only ems_metadata relationship tree" do
      it 'sets nothing' do
        parent_rel = rel_stub.create!(:relationship => 'ems_metadata', :ancestry => nil, :resource_type => 'VmOrTemplate', :resource_id => root.id)
        rel_stub.create!(:relationship => 'ems_metadata', :ancestry => parent_rel.id, :resource_type => 'VmOrTemplate', :resource_id => vm.id)

        migrate

        expect(vm.reload.ancestry).to eq(nil)
        expect(root.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(2)
      end
    end

    context "with rel type that isn't vm_or_template" do
      it 'sets nothing' do
        parent_rel = rel_stub.create!(:relationship => 'ems_metadata', :ancestry => nil, :resource_type => 'Host', :resource_id => root.id)
        rel_stub.create!(:relationship => 'ems_metadata', :ancestry => parent_rel.id, :resource_type => 'Host', :resource_id => vm.id)

        migrate

        expect(vm.reload.ancestry).to eq(nil)
        expect(root.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(2)
      end
    end

    context "with both genealogy and ems_metadata rels" do
      it 'only sets ancestry from genealogy rels' do
        invalid_parent_rel = rel_stub.create!(:relationship => 'ems_metadata', :ancestry => nil, :resource_type => 'VmOrTemplate', :resource_id => root.id)
        rel_stub.create!(:relationship => 'ems_metadata', :ancestry => invalid_parent_rel.id, :resource_type => 'VmOrTemplate', :resource_id => vm.id)
        parent_rel = rel_stub.create!(:relationship => 'genealogy', :ancestry => nil, :resource_type => 'VmOrTemplate', :resource_id => root.id)
        rel_stub.create!(:relationship => 'genealogy', :ancestry => parent_rel.id, :resource_type => 'VmOrTemplate', :resource_id => vm.id)

        migrate

        expect(vm.reload.ancestry).to eq(root.id.to_s)
        expect(root.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(2)
      end
    end
  end

  migration_context :down do
    context "multiple rels" do
      let!(:vm) { vm_stub.create!(:ancestry => '6/5/4') }
      it 'creates rel and removes ancestry' do
        migrate

        rel = rel_stub.first
        expect(rel.relationship).to eq('genealogy')
        expect(rel.ancestry).to eq('6/5/4')
        expect(rel.resource_type).to eq('VmOrTemplate')
        expect(rel.resource_id).to eq(vm.id)
      end
    end

    context "single rel" do
      let!(:vm) { vm_stub.create!(:ancestry => '645') }
      it 'creates rel and removes ancestry' do
        migrate

        rel = rel_stub.first
        expect(rel.relationship).to eq('genealogy')
        expect(rel.ancestry).to eq('645')
        expect(rel.resource_type).to eq('VmOrTemplate')
        expect(rel.resource_id).to eq(vm.id)
      end
    end
  end
end
