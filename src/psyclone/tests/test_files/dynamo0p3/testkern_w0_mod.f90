! BSD 3-Clause License
!
! Copyright (c) 2017, Science and Technology Facilities Council
! All rights reserved.
!
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions are met:
!
! * Redistributions of source code must retain the above copyright notice, this
!   list of conditions and the following disclaimer.
!
! * Redistributions in binary form must reproduce the above copyright notice,
!   this list of conditions and the following disclaimer in the documentation
!   and/or other materials provided with the distribution.
!
! * Neither the name of the copyright holder nor the names of its
!   contributors may be used to endorse or promote products derived from
!   this software without specific prior written permission.
!
! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
! AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
! IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
! DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
! FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
! DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
! SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
! CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
! OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
! OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
! -----------------------------------------------------------------------------
! Author R. Ford STFC Daresbury Lab

module testkern_w0_mod
  use argument_mod
  use kernel_mod
  use constants_mod
  type, extends(kernel_type) :: testkern_w0_type
     type(arg_type), dimension(2) :: meta_args =  &
          (/ arg_type(gh_field,gh_inc, w0),       &
             arg_type(gh_field,gh_read,w0)        &
           /)
     integer :: iterates_over = cells
   contains
     procedure, nopass :: code => testkern_w0_code
  end type testkern_w0_type
contains

  subroutine testkern_w0_code(nlayers, fld1, fld2, ndf_w0, undf_w0, map_w0)
    integer :: nlayers
    real(kind=r_def), dimension(:), intent(inout) :: fld1
    real(kind=r_def), dimension(:), intent(in)    :: fld2
    integer :: ndf_w0, undf_w0
    integer, dimension(:) :: map_w0
  end subroutine testkern_w0_code

end module testkern_w0_mod
